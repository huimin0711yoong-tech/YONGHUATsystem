-- =====================================================================
-- YONGHUAT SYSTEM — step 5: daily summary for the Alerts box
-- Gives every logged-in person today's numbers (red / orange orders,
-- top out-of-stock items) without showing staff the order details.
-- Paste into Supabase > SQL Editor and click Run. Safe to run twice.
-- =====================================================================

create or replace function public.daily_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role      text := public.my_role();
  v_today     date := (now() at time zone 'Asia/Kuala_Lumpur')::date;
  v_red       int;
  v_orange    int;
  v_lookback  int;
  v_topn      int;
  v_deleted   text;
  v_delivered text;
  v_excl      text[];
  v_result    jsonb;
begin
  if v_role is null then
    raise exception 'Please log in with an active account.';
  end if;

  -- Rule numbers from settings (with safe defaults)
  select
    coalesce((select case when value ~ '^\d+$' then value::int end from public.settings where key = 'red_days'), 3),
    coalesce((select case when value ~ '^\d+$' then value::int end from public.settings where key = 'orange_days'), 1),
    coalesce((select case when value ~ '^\d+$' then value::int end from public.settings where key = 'oos_lookback_days'), 30),
    coalesce((select case when value ~ '^\d+$' then value::int end from public.settings where key = 'top_oos_count'), 10),
    upper(coalesce((select value from public.settings where key = 'deleted_status_text'), 'DELETED')),
    upper(coalesce((select value from public.settings where key = 'delivered_status_text'), 'FULFILL')),
    coalesce((select array(select upper(trim(x)) from unnest(string_to_array(value, ',')) as x where trim(x) <> '')
              from public.settings where key = 'pending_exclude_so_status'), array['VOID', 'DRAFT'])
  into v_red, v_orange, v_lookback, v_topn, v_deleted, v_delivered, v_excl;

  with pending as (
    select so_no, so_date, amount
    from public.so_lines
    where upper(coalesce(delivery_status, '')) <> v_delivered
      and not (upper(coalesce(order_status, '')) = any (v_excl))
      and upper(coalesce(line_status, '')) <> v_deleted
  ),
  orders as (
    select so_no, v_today - min(so_date) as days, sum(amount) as amount
    from pending
    group by so_no
  ),
  oos as (
    select item, max(item_desc) as item_desc, count(*) as times, sum(amount) as rm
    from public.so_lines
    where upper(coalesce(line_status, '')) = v_deleted
      and so_date >= v_today - v_lookback
    group by item
    order by count(*) desc, sum(amount) desc
    limit v_topn
  )
  select jsonb_build_object(
    'today',          v_today,
    'red_days',       v_red,
    'orange_days',    v_orange,
    'top_n',          v_topn,
    'red',            (select count(*) from orders where days >= v_red),
    'orange',         (select count(*) from orders where days >= v_orange and days < v_red),
    'pending_orders', (select count(*) from orders),
    'pending_rm',     case when v_role in ('manager', 'owner') then (select coalesce(sum(amount), 0) from orders) end,
    'oos_items',      (select count(distinct item) from public.so_lines
                        where upper(coalesce(line_status, '')) = v_deleted and so_date >= v_today - v_lookback),
    'top_oos',        coalesce((select jsonb_agg(jsonb_build_object('item', item, 'desc', item_desc, 'times', times)
                                 order by times desc, rm desc) from oos), '[]'::jsonb),
    'last_upload',    (select max(upload_batch) from public.so_lines)
  ) into v_result;

  return v_result;
end;
$$;

revoke execute on function public.daily_summary() from public, anon;
grant  execute on function public.daily_summary() to authenticated;

select 'Step 5 finished' as result;
