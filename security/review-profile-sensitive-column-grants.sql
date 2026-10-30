-- REVIEW ONLY — NOT EXECUTED.
-- Existing auth.users INSERT trigger calls private.on_auth_user_created()
-- as SECURITY DEFINER and creates public profiles and initial role.
-- Verified defaults FALSE, profiles.status defaults active.
-- Revoke table-wide and any explicit column-level UPDATE grants before whitelisting.
-- PostgreSQL table-level REVOKE does not cancel pre-existing column grants.
-- Do not execute before testing in an isolated database clone.
BEGIN;
REVOKE UPDATE ON TABLE public.profiles FROM anon, authenticated;
REVOKE UPDATE ON TABLE public.company_profiles FROM anon, authenticated;
REVOKE UPDATE ON TABLE public.worker_profiles FROM anon, authenticated;
REVOKE UPDATE (id, full_name, phone, city, avatar_path, status, created_at)
ON TABLE public.profiles FROM anon, authenticated;
REVOKE UPDATE (user_id, company_name, nip, description, verified)
ON TABLE public.company_profiles FROM anon, authenticated;
REVOKE UPDATE (user_id, bio, experience_years, available, verified)
ON TABLE public.worker_profiles FROM anon, authenticated;

GRANT UPDATE (full_name, phone, city, avatar_path)
ON TABLE public.profiles TO authenticated;
GRANT UPDATE (company_name, nip, description)
ON TABLE public.company_profiles TO authenticated;
GRANT UPDATE (bio, experience_years, available)
ON TABLE public.worker_profiles TO authenticated;

-- Prevent direct client creation of profile rows, including forged verified/status.
-- The auth trigger is SECURITY DEFINER; confirm function owner and privileges
-- before running, as its INSERTs must remain operational.
REVOKE INSERT ON TABLE public.profiles FROM anon, authenticated;
REVOKE INSERT ON TABLE public.company_profiles FROM anon, authenticated;
REVOKE INSERT ON TABLE public.worker_profiles FROM anon, authenticated;
-- Column-level INSERT grants, if any, must also be revoked explicitly.
REVOKE INSERT (id, full_name, phone, city, avatar_path, status, created_at)
ON TABLE public.profiles FROM anon, authenticated;
REVOKE INSERT (user_id, company_name, nip, description, verified)
ON TABLE public.company_profiles FROM anon, authenticated;
REVOKE INSERT (user_id, bio, experience_years, available, verified)
ON TABLE public.worker_profiles FROM anon, authenticated;

-- RLS policies must remain enabled and restrict edits to owned records.
-- Verified flags must be updated exclusively through audited server-admin flows.
COMMIT;
