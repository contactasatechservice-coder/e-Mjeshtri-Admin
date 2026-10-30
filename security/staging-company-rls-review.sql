-- REVIEW-ONLY SQL DRAFT. NOT EXECUTED. Apply exclusively to isolated Staging after review.
-- Company publication requires verified company and active account.
-- Existing policies are replaced with a single restrictive condition per operation.
drop policy if exists company_insert_job on public.job_posts;
create policy company_insert_job on public.job_posts
for insert to authenticated
with check (
  company_id = (select auth.uid())
  and exists (
    select 1 from public.company_profiles cp
    join public.profiles p on p.id = cp.user_id
    where cp.user_id = (select auth.uid())
      and cp.verified is true and p.status = 'active'
  )
);
drop policy if exists company_update_job on public.job_posts;
create policy company_update_job on public.job_posts
for update to authenticated
using (
  company_id = (select auth.uid())
  and exists (
    select 1 from public.company_profiles cp
    join public.profiles p on p.id = cp.user_id
    where cp.user_id = (select auth.uid())
      and cp.verified is true and p.status = 'active'
  )
)
with check (
  company_id = (select auth.uid())
  and exists (
    select 1 from public.company_profiles cp
    join public.profiles p on p.id = cp.user_id
    where cp.user_id = (select auth.uid())
      and cp.verified is true and p.status = 'active'
  )
);
-- Do not let users set verification flags on initial profile INSERT.
revoke insert on public.company_profiles from anon, authenticated;
revoke insert on public.worker_profiles from anon, authenticated;
grant insert (user_id, company_name, nip, description) on public.company_profiles to authenticated;
grant insert (user_id, bio, experience_years, available) on public.worker_profiles to authenticated;
-- No INSERT policies for profiles are created here: existing deny-by-default is intentional.
-- A separately reviewed signup bootstrap is required before registration works.
-- Chat write policy intentionally withheld until membership creation and lifecycle are designed.
