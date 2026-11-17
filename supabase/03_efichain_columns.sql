-- =====================================================================
-- YONGHUAT SYSTEM — step 3: match the real eFichain Excel
-- Paste into Supabase > SQL Editor and click Run. Safe to run twice.
-- =====================================================================

-- Extra columns from the eFichain "Daily Order Details Fulfillment" export
alter table public.so_lines add column if not exists item_desc   text;          -- DESCRIPTION
alter table public.so_lines add column if not exists line_status text;          -- STATUS (DELETED = removed at picking)
alter table public.so_lines add column if not exists salesman    text;          -- SALESMAN
alter table public.so_lines add column if not exists division    text;          -- DIVISION CODE
alter table public.so_lines add column if not exists qty         numeric(12,2); -- S/O LOOSE QTY

create index if not exists so_lines_line_status_idx on public.so_lines (line_status);

-- Status words used by eFichain
update public.settings set value = 'DELETED',
  description = 'Item STATUS text in eFichain that means the item was deleted at picking'
  where key = 'deleted_status_text' and value = 'Deleted';

update public.settings set value = 'FULFILL',
  description = 'SHIP STATUS text in eFichain that means delivered'
  where key = 'delivered_status_text' and value = 'Delivered';

insert into public.settings (key, value, description) values
  ('pending_exclude_so_status', 'VOID', 'S/O STATUS values (comma separated) that are NOT counted as pending delivery')
on conflict (key) do nothing;

select 'Step 3 finished' as result;
