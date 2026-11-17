-- =====================================================================
-- YONGHUAT SYSTEM — make the boss the owner (run once after the boss signs up)
-- 1. Change the email below to the boss's login email (keep the quotes).
-- 2. Paste into Supabase > SQL Editor and click Run. Safe to run twice.
-- =====================================================================

update public.profiles
set role = 'owner', active = true
where lower(email) = lower('BOSS_EMAIL_HERE');

-- Check: you should see the boss with role = owner
select email, full_name, role, active from public.profiles order by created_at;
