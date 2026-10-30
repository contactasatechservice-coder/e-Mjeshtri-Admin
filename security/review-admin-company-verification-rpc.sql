-- REVIEW BEFORE APPLYING ON EXISTING SUPABASE PROJECT.
-- One authenticated admin RPC performs authorization, status update and audit atomically.
-- Keep privileged function in non-exposed schema? RPC requires exposed schema, so use
-- public with explicit REVOKE EXECUTE FROM PUBLIC and a narrow authenticated grant.
BEGIN;

CREATE OR REPLACE FUNCTION public.admin_set_company_verification(
  p_company_id uuid,
  p_verified boolean
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := (SELECT auth.uid());
BEGIN
  IF v_actor IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = v_actor AND role = 'super_admin'
  ) THEN
    RAISE EXCEPTION 'Not authorized' USING ERRCODE = '42501';
  END IF;

  UPDATE public.company_profiles
  SET verified = p_verified
  WHERE user_id = p_company_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Company not found' USING ERRCODE = 'P0002';
  END IF;

  INSERT INTO public.admin_audit_logs(actor_id, action, target_type, target_id)
  VALUES (
    v_actor,
    CASE WHEN p_verified THEN 'company_verified' ELSE 'company_unverified' END,
    'company',
    p_company_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_set_company_verification(uuid, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_set_company_verification(uuid, boolean) FROM anon;
GRANT EXECUTE ON FUNCTION public.admin_set_company_verification(uuid, boolean) TO authenticated;
COMMIT;
