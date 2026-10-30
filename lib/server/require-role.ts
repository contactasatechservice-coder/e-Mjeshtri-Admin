import 'server-only';
import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';

export type AppRole = 'citizen' | 'worker' | 'company' | 'super_admin';

/**
 * Use this helper in server components/actions before rendering role-restricted UI.
 * Every database mutation must independently enforce ownership and permissions.
 */
export async function requireRole(allowedRoles: readonly AppRole[]) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) throw new Error('Supabase environment variables are missing');

  const cookieStore = await cookies();
  const client = createServerClient(url, key, {
    cookies: {
      getAll: () => cookieStore.getAll(),
      setAll: (items) => {
        try {
          items.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
        } catch {
          // Server Components may be read-only; middleware refreshes session cookies.
        }
      },
    },
  });

  const { data: { user }, error: authError } = await client.auth.getUser();
  if (authError || !user) redirect('/hyrje');

  const { data: roles, error: rolesError } = await client
    .from('user_roles')
    .select('role')
    .eq('user_id', user.id);

  if (rolesError) throw new Error('Unable to verify account permissions');
  const permitted = roles?.some((row) => allowedRoles.includes(row.role as AppRole));
  if (!permitted) redirect('/panel');

  return { user, client };
}
