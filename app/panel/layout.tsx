import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import type { ReactNode } from 'react';

/**
 * Server-side authentication gate for every /panel route.
 * Do not use this as a substitute for RLS or server-side role authorization.
 */
export default async function PanelLayout({ children }: { children: ReactNode }) {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) {
    throw new Error('Supabase environment variables are missing');
  }

  const cookieStore = await cookies();
  const client = createServerClient(url, key, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(values: { name: string; value: string; options?: CookieOptions }[]) {
        // Server Components cannot always write cookies; session refresh
        // should also be handled by the Next.js request proxy/middleware.
        try {
          values.forEach(({ name, value, options }) => {
            cookieStore.set(name, value, options);
          });
        } catch {
          // Read-only Server Component render context.
        }
      },
    },
  });

  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user) {
    redirect('/hyrje');
  }

  return <>{children}</>;
}
