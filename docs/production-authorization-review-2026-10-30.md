# Production authorization review — 2026-10-30

Status: **read-only review; no production changes applied**.

## Observed
- `company_profiles.verified` and `worker_profiles.verified`: column INSERT granted to authenticated; direct column UPDATE not listed for authenticated.
- `profiles.status`: UPDATE privilege listed for authenticated and anon.
- `profiles.update_own_profile` currently has USING and WITH CHECK requiring status='active'; this can prevent reactivation of a suspended row through that policy, but does not by itself prohibit changing an active row's status.
- `job_posts.company_insert_job` and `company_update_job` do not currently require a verified company.
- PostgreSQL grants and RLS are independent. Column grants alone do not prove that a request is executable; test with actual authenticated sessions in a disposable environment.
- PostgreSQL permissive policies combine with OR. Replace existing permissive policies rather than adding a second permissive policy.

## Required before any production migration
1. Inspect table-level privileges, other policies, triggers and auth signup flow.
2. Confirm whether account creation is performed by auth triggers/service role; revoke sensitive INSERT columns from untrusted roles without breaking signup.
3. Prevent client updates to `profiles.status` while allowing legitimate edits to full_name, phone, city and avatar_path.
4. Prevent user-supplied `verified=true` on INSERT for worker/company profiles; default false and enforce through grants or server-owned trigger/validation.
5. Verify administrator-only approval path is server-authorized and audited.
6. Test: active company unverified cannot INSERT/UPDATE jobs; verified company can; non-company cannot; suspended company cannot; citizen cannot change role/status/verified; multi-role sessions cannot cross access boundaries.
7. Review `security/review-company-job-policies.sql` alongside `security/staging-company-rls-review.sql` before applying either; avoid duplicate or contradictory changes.
8. Run tests on an isolated clone and obtain approval before modifying the live database.

No test users, production mutations or privilege changes have been performed by this audit.
