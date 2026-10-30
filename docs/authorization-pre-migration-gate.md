# Supabase authorization pre-migration gate — 2026-10-30

This report records SELECT-only inspection of the existing e-Mjeshtri Supabase database. **No SQL mutation or real role-based integration test has been executed.**

## Verified
- `private.on_auth_user_created()` is owned by `postgres` and marked SECURITY DEFINER. It is attached to `auth.users` INSERT. The function creates profiles, user_roles, and optional company/worker profiles.
- `company_profiles.verified` and `worker_profiles.verified` default to false.
- `profiles.status` defaults to active.
- Existing `job_posts` write policies do not require `company_profiles.verified=true`.
- Table-level INSERT privileges currently exist for `anon` on profiles, worker_profiles, company_profiles, job_posts; UPDATE privileges exist for `anon` on these tables.
- Table-level INSERT exists for `authenticated` on profiles, worker_profiles, company_profiles, job_posts; UPDATE exists for `authenticated` on job_posts.
- A grant alone does not prove access: RLS and other constraints still apply. Do not infer an exploit without testing with real role sessions.

## Important nuance
The existing signup trigger is SECURITY DEFINER owned by postgres; it is expected to retain permission to bootstrap new profiles when client INSERT grants are revoked. This remains **untested** after proposed changes.

## Migration review requirements
1. Review `security/review-profile-sensitive-column-grants.sql` for both table-level and column-level grant revocations, including all inherited roles.
2. Review `security/review-company-job-policies.sql` to ensure all permissive policies allowing writes are replaced and no alternate policy permits bypass.
3. In an isolated database clone, test new citizen, worker and company signup, and confirm worker/company verified=false.
4. Test own profile edits, status and verified escalation attempts, verified/unverified/suspended company job writes and cross-account access with authenticated sessions, not service_role.
5. Review how super_admin verifies companies and changes profile status: privileged changes must be server-side, authorized, and audited.
6. Inspect staging logs and repeat the preflight SQL; only then consider production rollout after approval.

## CI limitations
The Node tests in `tests/security-guards.test.mjs` and `tests/security-sql-drafts.test.mjs` inspect code and SQL text. They **do not** execute PostgreSQL RLS policies or prove runtime authorization.
