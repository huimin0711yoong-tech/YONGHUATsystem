-- =====================================================================
-- YONGHUAT SYSTEM — step 4: DRAFT orders are NOT counted as pending delivery
-- Paste into Supabase > SQL Editor and click Run. Safe to run twice.
-- =====================================================================

insert into public.settings (key, value, description) values
  ('pending_exclude_so_status', 'VOID,DRAFT', 'S/O STATUS values (comma separated) that are NOT counted as pending delivery')
on conflict (key) do update set value = 'VOID,DRAFT', updated_at = now()
  where public.settings.value = 'VOID';

select key, value from public.settings where key = 'pending_exclude_so_status';
