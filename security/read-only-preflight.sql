-- READ-ONLY security preflight; safe to run on the existing database.
-- Checks policy presence, grants, defaults, and signup trigger metadata.
SELECT n.nspname AS schema_name, c.relname AS table_name,
       c.relrowsecurity AS rls_enabled,
       count(p.oid) AS policy_count
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pg_policy p ON p.polrelid = c.oid
WHERE n.nspname = 'public'
  AND c.relname IN ('profiles','user_roles','company_profiles','worker_profiles','job_posts')
GROUP BY n.nspname,c.relname,c.relrowsecurity
ORDER BY c.relname;

SELECT table_name,column_name,column_default
FROM information_schema.columns
WHERE table_schema='public'
AND ((table_name IN ('worker_profiles','company_profiles') AND column_name='verified')
 OR (table_name='profiles' AND column_name='status'))
ORDER BY table_name;

SELECT table_name,column_name,grantee,privilege_type
FROM information_schema.column_privileges
WHERE table_schema='public'
AND table_name IN ('profiles','worker_profiles','company_profiles')
AND column_name IN ('status','verified')
AND grantee IN ('anon','authenticated')
ORDER BY table_name,column_name,grantee,privilege_type;

SELECT t.tgname AS trigger_name, n.nspname AS trigger_schema,
       p.proname AS function_name,p.prosecdef AS security_definer
FROM pg_trigger t
JOIN pg_class c ON c.oid=t.tgrelid
JOIN pg_namespace n ON n.oid=c.relnamespace
JOIN pg_proc p ON p.oid=t.tgfoid
WHERE n.nspname='auth' AND c.relname='users'
AND t.tgname='on_auth_user_created' AND NOT t.tgisinternal;
