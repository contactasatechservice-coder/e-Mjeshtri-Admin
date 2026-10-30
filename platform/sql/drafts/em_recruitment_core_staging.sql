-- e-Mjeshtri 2.0 recruitment core. REVIEW/STAGING ONLY: transaction rolls back.
-- Companies and memberships require trusted provisioning; browser users cannot create themselves as owners.
BEGIN;
CREATE TABLE public.em_companies(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text NOT NULL CHECK(length(trim(name)) BETWEEN 2 AND 160),created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.em_company_memberships(business_id uuid NOT NULL REFERENCES public.em_companies(id) ON DELETE CASCADE,user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,role text NOT NULL CHECK(role IN ('owner','manager','recruiter')),status text NOT NULL DEFAULT 'active' CHECK(status IN ('active','suspended')),PRIMARY KEY(business_id,user_id));
CREATE TABLE public.em_job_postings(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),business_id uuid NOT NULL REFERENCES public.em_companies(id) ON DELETE CASCADE,title text NOT NULL CHECK(length(trim(title)) BETWEEN 3 AND 180),city text NOT NULL DEFAULT '',description text NOT NULL DEFAULT '',employment_type text NOT NULL DEFAULT 'full_time',salary_min numeric(12,2),salary_max numeric(12,2),currency text NOT NULL DEFAULT 'ALL',status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','published','closed')),published_at timestamptz,created_at timestamptz NOT NULL DEFAULT now(),CHECK(salary_min IS NULL OR salary_min>=0),CHECK(salary_max IS NULL OR salary_max>=0),CHECK(salary_min IS NULL OR salary_max IS NULL OR salary_max>=salary_min));
CREATE TABLE public.em_candidate_profiles(user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,full_name text NOT NULL DEFAULT '',headline text NOT NULL DEFAULT '',summary text NOT NULL DEFAULT '',city text NOT NULL DEFAULT '',created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE public.em_candidate_documents(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,storage_path text NOT NULL UNIQUE,file_name text NOT NULL,created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(id,user_id));
CREATE TABLE public.em_job_applications(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),job_id uuid NOT NULL REFERENCES public.em_job_postings(id) ON DELETE CASCADE,candidate_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,cv_document_id uuid,status text NOT NULL DEFAULT 'submitted' CHECK(status IN ('submitted','reviewing','interview','rejected','hired')),created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(job_id,candidate_id),FOREIGN KEY(cv_document_id,candidate_id) REFERENCES public.em_candidate_documents(id,user_id));
ALTER TABLE public.em_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.em_company_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.em_job_postings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.em_candidate_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.em_candidate_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.em_job_applications ENABLE ROW LEVEL SECURITY;
CREATE POLICY em_members_self ON public.em_company_memberships FOR SELECT TO authenticated USING(user_id=(select auth.uid()));
CREATE POLICY em_companies_members ON public.em_companies FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.em_company_memberships m WHERE m.business_id=em_companies.id AND m.user_id=(select auth.uid()) AND m.status='active'));
CREATE POLICY em_jobs_public ON public.em_job_postings FOR SELECT TO anon,authenticated USING(status='published');
CREATE POLICY em_jobs_company ON public.em_job_postings FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.em_company_memberships m WHERE m.business_id=em_job_postings.business_id AND m.user_id=(select auth.uid()) AND m.status='active'));
CREATE POLICY em_candidates_self ON public.em_candidate_profiles FOR ALL TO authenticated USING(user_id=(select auth.uid())) WITH CHECK(user_id=(select auth.uid()));
CREATE POLICY em_docs_self ON public.em_candidate_documents FOR SELECT TO authenticated USING(user_id=(select auth.uid()));
CREATE POLICY em_app_candidate_read ON public.em_job_applications FOR SELECT TO authenticated USING(candidate_id=(select auth.uid()));
CREATE POLICY em_app_company_read ON public.em_job_applications FOR SELECT TO authenticated USING(EXISTS(SELECT 1 FROM public.em_job_postings j JOIN public.em_company_memberships m ON m.business_id=j.business_id WHERE j.id=em_job_applications.job_id AND m.user_id=(select auth.uid()) AND m.status='active' AND m.role IN ('owner','manager','recruiter')));
-- Candidate profile writes are restricted to the signed-in user.
-- Company vacancy creation requires an active owner/manager/recruiter membership.
CREATE POLICY em_jobs_company_insert ON public.em_job_postings FOR INSERT TO authenticated WITH CHECK(
 EXISTS(SELECT 1 FROM public.em_company_memberships m WHERE m.business_id=em_job_postings.business_id AND m.user_id=(select auth.uid()) AND m.status='active' AND m.role IN ('owner','manager','recruiter'))
 AND status='draft' AND published_at IS NULL
);
-- Editing and publishing require a trusted server workflow; direct UPDATE is denied.
-- A candidate may apply only to a published job, for themselves, once.
CREATE POLICY em_application_candidate_insert ON public.em_job_applications FOR INSERT TO authenticated WITH CHECK(
 candidate_id=(select auth.uid()) AND status='submitted'
 AND EXISTS(SELECT 1 FROM public.em_job_postings j WHERE j.id=em_job_applications.job_id AND j.status='published')
);
-- CV metadata and binary uploads remain blocked until private Storage RLS is configured.
-- Default deny: company/member creation and changes, job UPDATE, document writes, application UPDATE/DELETE.
-- Requires secure workflows, GRANT review, and private Storage bucket policies before deployment.
SELECT count(*) AS em_rls_enabled FROM pg_class WHERE oid IN ('public.em_companies'::regclass,'public.em_company_memberships'::regclass,'public.em_job_postings'::regclass,'public.em_candidate_profiles'::regclass,'public.em_candidate_documents'::regclass,'public.em_job_applications'::regclass) AND relrowsecurity;
ROLLBACK;