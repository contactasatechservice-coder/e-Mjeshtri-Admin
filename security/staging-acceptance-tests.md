# Staging security acceptance tests — executable test plan (not yet run)

Prerequisites: isolated Supabase Staging, disposable users and company records, never production identities.

| Test | Actor | Operation | Expected |
|---|---|---|---|
| C01 | Citizen | INSERT job_posts | Denied |
| C02 | Unverified company | INSERT job_posts | Denied |
| C03 | Verified active company | INSERT own job_posts | Allowed |
| C04 | Verified company | INSERT for another company_id | Denied |
| C05 | Unverified company | UPDATE existing job_posts | Denied |
| C06 | Verified company | UPDATE another company's job | Denied |
| C07 | Authenticated user | INSERT company_profiles verified=true | Denied |
| C08 | Authenticated user | INSERT worker_profiles verified=true | Denied |
| C09 | Authenticated user | INSERT/UPDATE user_roles | Denied |
| C10 | Non-member | SELECT another conversation/messages | Denied |
| C11 | Member | SELECT own conversation/messages | Allowed |
| C12 | Member | INSERT messages | Currently denied; implement only after safe chat-write design |
| C13 | Anon | INSERT job_posts | Denied |

Check Auth signup bootstrap independently: role assignment from server allowlist, never user_metadata as authority, company verified=false, worker verified=false, and profile ownership.
Inspect policy combinations: permissive policies are ORed. Validate grants, existing data, Auth hooks and API routes before executing SQL.
Run SQL in a transaction in Staging when possible; validate rollback and verify RLS with real authenticated JWT contexts.
