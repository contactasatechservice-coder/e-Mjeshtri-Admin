-- e-Mjeshtri 2.0: integrity patch for proposed em_* schema.
-- STAGING ONLY. Run AFTER phase1 schema, and only after PostgreSQL/RLS tests.
-- This is not a complete production migration.
BEGIN;

-- At most one accepted offer per service request, including concurrent transactions.
CREATE UNIQUE INDEX IF NOT EXISTS em_one_accepted_offer_per_request
ON public.em_service_offers (request_id)
WHERE status = 'accepted';

-- Ensure application CV belongs to the same candidate.
-- The composite FK also covers UPDATE, not just initial INSERT.
CREATE UNIQUE INDEX IF NOT EXISTS em_candidate_document_owner_pair
ON public.em_candidate_documents (id, user_id);

ALTER TABLE public.em_job_applications
ADD CONSTRAINT em_application_cv_owner_fk
FOREIGN KEY (cv_document_id, candidate_id)
REFERENCES public.em_candidate_documents (id, user_id);

-- Guard against modifying immutable ownership via direct UPDATE.
-- Policies and trusted server-side transition logic are still required.
CREATE OR REPLACE FUNCTION public.em_reject_identity_changes()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER AS $$
BEGIN
  IF TG_TABLE_NAME = 'em_job_applications' AND
     (NEW.job_id IS DISTINCT FROM OLD.job_id OR
      NEW.candidate_id IS DISTINCT FROM OLD.candidate_id) THEN
    RAISE EXCEPTION 'Application identity cannot be changed';
  END IF;
  IF TG_TABLE_NAME = 'em_service_requests' AND
     NEW.customer_id IS DISTINCT FROM OLD.customer_id THEN
    RAISE EXCEPTION 'Request owner cannot be changed';
  END IF;
  IF TG_TABLE_NAME = 'em_service_offers' AND
     (NEW.request_id IS DISTINCT FROM OLD.request_id OR
      NEW.professional_id IS DISTINCT FROM OLD.professional_id) THEN
    RAISE EXCEPTION 'Offer identity cannot be changed';
  END IF;
  RETURN NEW;
END $$;

CREATE TRIGGER em_application_identity_guard
BEFORE UPDATE ON public.em_job_applications
FOR EACH ROW EXECUTE FUNCTION public.em_reject_identity_changes();
CREATE TRIGGER em_request_identity_guard
BEFORE UPDATE ON public.em_service_requests
FOR EACH ROW EXECUTE FUNCTION public.em_reject_identity_changes();
CREATE TRIGGER em_offer_identity_guard
BEFORE UPDATE ON public.em_service_offers
FOR EACH ROW EXECUTE FUNCTION public.em_reject_identity_changes();

-- SAFETY: review and run on isolated staging first. No production changes.
ROLLBACK;
