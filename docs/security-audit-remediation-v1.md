# e-Mjeshtri — Security audit remediation (draft, no production execution)

Base: `web-rebuild-nextjs`. This branch is for review only.

## Confirmed from read-only Supabase inspection
- `job_posts.company_insert_job` checks company ownership and active profile but not `company_profiles.verified`.
- `job_posts.company_update_job` checks company ownership but not verification.
- `company_profiles.verified` and `worker_profiles.verified` are not UPDATE-able by `authenticated`, but INSERT privileges exist at column level. No INSERT RLS policy was observed; keep deny-by-default until safe signup bootstrap is designed.
- `user_roles` has no INSERT/UPDATE privileges for `authenticated`.
- `messages` and `conversations` have read policies but no INSERT policies in the inspected schema.
- No functions/triggers were found in `public`; auth schema functions were not audited.
- `lib/supabase.ts` uses browser client and public environment variables; server auth flows remain to be inventoried.

## Required checks before any migration
1. Confirm isolated Staging Supabase project, credentials and Storage.
2. Inspect `pg_policies`, `information_schema.role_table_grants`, column grants and Auth hooks.
3. Design server-owned signup bootstrap: never trust client-supplied role/verified/status.
4. Apply verified-company policy to both INSERT and UPDATE of jobs; test existing jobs for compatibility.
5. Protect `verified` on INSERT (column grants or server-only creation) and ensure safe default false.
6. Implement chat writes through authenticated server route or strictly scoped RLS; validate membership and sender.
7. Test anonymous, citizen, worker, unverified company, verified company and admin cases.
8. Re-run security advisors and end-to-end tests, then seek Super Admin approval.

## Release safety
Do not run these changes on Production. No schema modifications or deployment have been performed by this audit.
