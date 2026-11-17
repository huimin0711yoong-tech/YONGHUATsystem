-- =====================================================================
-- YONGHUAT SYSTEM — step 6: close extra access to background functions
-- These functions run automatically (triggers). Nobody needs to call them
-- directly, so we remove that permission. Safe to run twice.
-- Paste into Supabase > SQL Editor and click Run.
-- =====================================================================

-- Trigger functions: run automatically only
revoke execute on function public.handle_new_user()        from public, anon, authenticated;
revoke execute on function public.protect_profile()        from public, anon, authenticated;
revoke execute on function public.requests_before_update() from public, anon, authenticated;
revoke execute on function public.requests_audit()         from public, anon, authenticated;
-- Extra safety: Supabase's own sign-up service keeps access to the new-user function
grant  execute on function public.handle_new_user()        to supabase_auth_admin;

-- Used by the security rules and the app: logged-in users only (not visitors)
revoke execute on function public.my_role() from public, anon;
grant  execute on function public.my_role() to authenticated;

revoke execute on function public.write_audit(text, text, text, jsonb) from public, anon;
grant  execute on function public.write_audit(text, text, text, jsonb) to authenticated;

revoke execute on function public.daily_summary() from public, anon;
grant  execute on function public.daily_summary() to authenticated;

select 'Step 6 finished' as result;
