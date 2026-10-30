-- REVIEW ONLY. Do not run on production before validating signup triggers,
-- column privileges and role-specific integration tests.
-- Replace the two existing permissive policies; adding a second policy
-- would NOT restrict the old ones because permissive policies combine with OR.
BEGIN;
DROP POLICY IF EXISTS company_insert_job ON public.job_posts;
CREATE POLICY company_insert_job ON public.job_posts
  FOR INSERT TO authenticated
  WITH CHECK (
    company_id = (select auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (select auth.uid()) AND p.status = 'active'
    )
    AND EXISTS (
      SELECT 1 FROM public.user_roles r
      WHERE r.user_id = (select auth.uid()) AND r.role = 'company'
    )
    AND EXISTS (
      SELECT 1 FROM public.company_profiles c
      WHERE c.user_id = (select auth.uid()) AND c.verified IS TRUE
    )
  );

DROP POLICY IF EXISTS company_update_job ON public.job_posts;
CREATE POLICY company_update_job ON public.job_posts
  FOR UPDATE TO authenticated
  USING (
    company_id = (select auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (select auth.uid()) AND p.status = 'active'
    )
    AND EXISTS (
      SELECT 1 FROM public.user_roles r
      WHERE r.user_id = (select auth.uid()) AND r.role = 'company'
    )
    AND EXISTS (
      SELECT 1 FROM public.company_profiles c
      WHERE c.user_id = (select auth.uid()) AND c.verified IS TRUE
    )
  )
  WITH CHECK (
    company_id = (select auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = (select auth.uid()) AND p.status = 'active'
    )
    AND EXISTS (
      SELECT 1 FROM public.user_roles r
      WHERE r.user_id = (select auth.uid()) AND r.role = 'company'
    )
    AND EXISTS (
      SELECT 1 FROM public.company_profiles c
      WHERE c.user_id = (select auth.uid()) AND c.verified IS TRUE
    )
  );
COMMIT;
