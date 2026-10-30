import Link from 'next/link';
import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import { LogoutButton } from './logout-button';

const destinations = {
  citizen: { title: 'Qytetar', href: '/panel/qytetar' },
  worker: { title: 'Mjeshtër', href: '/panel/mjeshter' },
  company: { title: 'Kompani', href: '/panel/kompani' },
  super_admin: { title: 'Super Admin', href: '/panel/admin' },
} as const;

type Role = keyof typeof destinations;

export default async function Panel() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) throw new Error('Supabase environment variables are missing');
  const store = await cookies();
  const client = createServerClient(url, key, {
    cookies: {
      getAll: () => store.getAll(),
      setAll: (items: { name: string; value: string; options?: CookieOptions }[]) => {
        try {
          items.forEach(({ name, value, options }) => store.set(name, value, options));
        } catch {
          // Middleware refreshes cookies when server components cannot write them.
        }
      },
    },
  });
  const { data: { user }, error: authError } = await client.auth.getUser();
  if (authError || !user) redirect('/hyrje');

  const { data, error } = await client.from('user_roles')
    .select('role').eq('user_id', user.id);
  if (error) throw new Error('Nuk u verifikuan rolet e llogarisë');

  const roles = [...new Set((data ?? []).map(row => row.role))]
    .filter((role): role is Role => Object.prototype.hasOwnProperty.call(destinations, role));

  // Single-role users go straight to their authorized panel.
  if (roles.length === 1) redirect(destinations[roles[0]].href);

  return <main className="shell">
    <header className="top"><Link href="/" className="logo">e-Mjeshtri</Link><LogoutButton /></header>
    <section className="auth">
      <h1>{roles.length ? 'Zgjidh panelin tënd' : 'Llogaria nuk ka ende një rol aktiv'}</h1>
      {roles.length ? <nav aria-label="Panelet e disponueshme">
        {roles.map(role => <p key={role}><Link href={destinations[role].href}>{destinations[role].title}</Link></p>)}
      </nav> : <p className="small">Kontakto mbështetjen nëse roli nuk është aktivizuar.</p>}
    </section>
  </main>;
}
