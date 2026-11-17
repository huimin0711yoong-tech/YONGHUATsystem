-- =====================================================================
-- YONGHUAT SYSTEM — database setup (step 1)
-- Paste this whole file into Supabase > SQL Editor and click Run.
-- Safe to run more than once.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. PROFILES (one row per user: name, role, active)
-- ---------------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  email      text,
  full_name  text not null default '',
  role       text not null default 'staff' check (role in ('owner', 'manager', 'staff')),
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

-- Role of the logged-in user (null if not logged in or not active).
create or replace function public.my_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid()
    and p.active = true
$$;

-- ---------------------------------------------------------------------
-- 2. AUDIT LOG (who did what, when)
-- ---------------------------------------------------------------------
create table if not exists public.audit_log (
  id         bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  who        uuid default auth.uid(),
  who_email  text,
  action     text not null,
  table_name text,
  record_id  text,
  details    jsonb
);

create or replace function public.write_audit(
  p_action text, p_table text, p_record text, p_details jsonb default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Logged-in users must be active. The SQL Editor (auth.uid() is null) may log too.
  if auth.uid() is not null and public.my_role() is null then
    raise exception 'Your account is not active.';
  end if;
  insert into public.audit_log (who, who_email, action, table_name, record_id, details)
  values (
    auth.uid(),
    (select p.email from public.profiles p where p.id = auth.uid()),
    p_action, p_table, p_record, p_details
  );
end;
$$;

revoke execute on function public.write_audit(text, text, text, jsonb) from public, anon;
grant  execute on function public.write_audit(text, text, text, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 3. NEW USER -> PROFILE (automatic on sign-up)
-- ---------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------
-- 4. ONLY THE OWNER CAN CHANGE ROLE / ACTIVE (SQL Editor also allowed)
-- ---------------------------------------------------------------------
create or replace function public.protect_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id is distinct from old.id or new.email is distinct from old.email then
    raise exception 'You cannot change the user id or email here.';
  end if;

  if new.role is distinct from old.role or new.active is distinct from old.active then
    if auth.uid() is not null and public.my_role() is distinct from 'owner' then
      raise exception 'Only the boss (owner) can change roles or turn accounts on/off.';
    end if;
    insert into public.audit_log (who, who_email, action, table_name, record_id, details)
    values (
      auth.uid(),
      (select p.email from public.profiles p where p.id = auth.uid()),
      'role change', 'profiles', new.id::text,
      jsonb_build_object(
        'email', new.email,
        'old_role', old.role, 'new_role', new.role,
        'old_active', old.active, 'new_active', new.active
      )
    );
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_protect on public.profiles;
create trigger profiles_protect
  before update on public.profiles
  for each row execute function public.protect_profile();

-- ---------------------------------------------------------------------
-- 5. SETTINGS (rule numbers — never hard-coded in the pages)
-- ---------------------------------------------------------------------
create table if not exists public.settings (
  key         text primary key,
  value       text not null,
  description text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid default auth.uid()
);

insert into public.settings (key, value, description) values
  ('red_days',             '3',         'Pending delivery this many days or more = RED'),
  ('orange_days',          '1',         'Pending delivery from this many days (up to red_days - 1) = ORANGE'),
  ('top_oos_count',        '10',        'How many out-of-stock items to show in the Top list'),
  ('oos_lookback_days',    '30',        'Top out-of-stock list only counts sales orders from the last N days'),
  ('deleted_status_text',  'Deleted',   'Order status text in eFichain that means the item was deleted'),
  ('delivered_status_text','Delivered', 'Delivery status text in eFichain that means delivered'),
  ('alert_hour',           '8',         'Daily summary shows from this hour (24h clock, Malaysia time)')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------
-- 6. SO_LINES (rows from the eFichain sales fulfillment Excel)
-- ---------------------------------------------------------------------
create table if not exists public.so_lines (
  id              uuid primary key default gen_random_uuid(),
  created_at      timestamptz not null default now(),
  created_by      uuid default auth.uid(),
  so_no           text not null,
  customer        text,
  so_date         date,
  invoice_date    date,
  item            text not null,
  amount          numeric(12,2) not null default 0,
  order_status    text,
  delivery_status text,
  upload_batch    text
);

-- One row per sales order + item, so uploading the same Excel twice updates instead of doubling.
create unique index if not exists so_lines_so_item_key on public.so_lines (so_no, item);
create index if not exists so_lines_so_date_idx on public.so_lines (so_date);

-- ---------------------------------------------------------------------
-- 7. REQUESTS (staff forms: arrange delivery / need to reorder)
-- ---------------------------------------------------------------------
create table if not exists public.requests (
  id          uuid primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  created_by  uuid default auth.uid(),
  type        text not null check (type in ('delivery', 'reorder')),
  so_no       text,
  item        text,
  qty         numeric(12,2),
  needed_date date,
  note        text,
  status      text not null default 'new'
              check (status in ('new', 'approved', 'rejected', 'done', 'cancelled')),
  handled_by  uuid,
  handled_at  timestamptz
);

create index if not exists requests_created_by_idx on public.requests (created_by);
create index if not exists requests_status_idx on public.requests (status);

-- Fill in who handled it; log create and status changes.
create or replace function public.requests_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.created_by := old.created_by;  -- nobody can change who made the form
  new.created_at := old.created_at;
  if new.status is distinct from old.status and new.status in ('approved', 'rejected', 'done') then
    new.handled_by := auth.uid();
    new.handled_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists requests_before_update on public.requests;
create trigger requests_before_update
  before update on public.requests
  for each row execute function public.requests_before_update();

create or replace function public.requests_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := (select p.email from public.profiles p where p.id = auth.uid());
begin
  if tg_op = 'INSERT' then
    insert into public.audit_log (who, who_email, action, table_name, record_id, details)
    values (auth.uid(), v_email, 'create', 'requests', new.id::text,
            jsonb_build_object('type', new.type, 'so_no', new.so_no, 'item', new.item, 'qty', new.qty));
  elsif new.status is distinct from old.status then
    insert into public.audit_log (who, who_email, action, table_name, record_id, details)
    values (auth.uid(), v_email, 'status change', 'requests', new.id::text,
            jsonb_build_object('from', old.status, 'to', new.status));
  end if;
  return new;
end;
$$;

drop trigger if exists requests_audit on public.requests;
create trigger requests_audit
  after insert or update on public.requests
  for each row execute function public.requests_audit();

-- ---------------------------------------------------------------------
-- 8. AI BRIEFS (saved only after a person ticks "I have checked this")
-- ---------------------------------------------------------------------
create table if not exists public.ai_briefs (
  id         uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  prompt     text not null,
  answer     text not null,
  checked    boolean not null default false check (checked = true)
);

-- ---------------------------------------------------------------------
-- 9. ROW LEVEL SECURITY (the real protection)
-- ---------------------------------------------------------------------
alter table public.profiles  enable row level security;
alter table public.audit_log enable row level security;
alter table public.settings  enable row level security;
alter table public.so_lines  enable row level security;
alter table public.requests  enable row level security;
alter table public.ai_briefs enable row level security;

-- profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.my_role() in ('manager', 'owner'));

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid() or public.my_role() = 'owner')
  with check (id = auth.uid() or public.my_role() = 'owner');

drop policy if exists profiles_delete on public.profiles;
create policy profiles_delete on public.profiles for delete to authenticated
  using (public.my_role() = 'owner');

-- audit_log: manager and owner read; writes only through the functions above
drop policy if exists audit_select on public.audit_log;
create policy audit_select on public.audit_log for select to authenticated
  using (public.my_role() in ('manager', 'owner'));

-- settings: everyone logged in reads, only owner edits
drop policy if exists settings_select on public.settings;
create policy settings_select on public.settings for select to authenticated
  using (public.my_role() is not null);

drop policy if exists settings_insert on public.settings;
create policy settings_insert on public.settings for insert to authenticated
  with check (public.my_role() = 'owner');

drop policy if exists settings_update on public.settings;
create policy settings_update on public.settings for update to authenticated
  using (public.my_role() = 'owner') with check (public.my_role() = 'owner');

drop policy if exists settings_delete on public.settings;
create policy settings_delete on public.settings for delete to authenticated
  using (public.my_role() = 'owner');

-- so_lines: manager and owner see, upload, edit; owner deletes; staff none
drop policy if exists so_lines_select on public.so_lines;
create policy so_lines_select on public.so_lines for select to authenticated
  using (public.my_role() in ('manager', 'owner'));

drop policy if exists so_lines_insert on public.so_lines;
create policy so_lines_insert on public.so_lines for insert to authenticated
  with check (public.my_role() in ('manager', 'owner'));

drop policy if exists so_lines_update on public.so_lines;
create policy so_lines_update on public.so_lines for update to authenticated
  using (public.my_role() in ('manager', 'owner'))
  with check (public.my_role() in ('manager', 'owner'));

drop policy if exists so_lines_delete on public.so_lines;
create policy so_lines_delete on public.so_lines for delete to authenticated
  using (public.my_role() = 'owner');

-- requests: staff own rows; manager all; owner all + delete
drop policy if exists requests_select on public.requests;
create policy requests_select on public.requests for select to authenticated
  using (
    public.my_role() in ('manager', 'owner')
    or (public.my_role() = 'staff' and created_by = auth.uid())
  );

drop policy if exists requests_insert on public.requests;
create policy requests_insert on public.requests for insert to authenticated
  with check (
    public.my_role() in ('staff', 'manager', 'owner')
    and created_by = auth.uid()
    and status = 'new'
  );

-- staff: edit own form only while still 'new', and may only keep it 'new' or cancel it
drop policy if exists requests_update_staff on public.requests;
create policy requests_update_staff on public.requests for update to authenticated
  using (public.my_role() = 'staff' and created_by = auth.uid() and status = 'new')
  with check (public.my_role() = 'staff' and created_by = auth.uid() and status in ('new', 'cancelled'));

drop policy if exists requests_update_manager on public.requests;
create policy requests_update_manager on public.requests for update to authenticated
  using (public.my_role() in ('manager', 'owner'))
  with check (public.my_role() in ('manager', 'owner'));

drop policy if exists requests_delete on public.requests;
create policy requests_delete on public.requests for delete to authenticated
  using (public.my_role() = 'owner');

-- ai_briefs: manager and owner
drop policy if exists ai_briefs_select on public.ai_briefs;
create policy ai_briefs_select on public.ai_briefs for select to authenticated
  using (public.my_role() in ('manager', 'owner'));

drop policy if exists ai_briefs_insert on public.ai_briefs;
create policy ai_briefs_insert on public.ai_briefs for insert to authenticated
  with check (public.my_role() in ('manager', 'owner') and created_by = auth.uid());

drop policy if exists ai_briefs_delete on public.ai_briefs;
create policy ai_briefs_delete on public.ai_briefs for delete to authenticated
  using (public.my_role() = 'owner');

-- Done.
select 'YONGHUAT database setup finished' as result;
