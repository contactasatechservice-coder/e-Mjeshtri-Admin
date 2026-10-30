import Link from 'next/link';
import { requireRole } from '@/lib/server/require-role';
import { setCompanyVerification } from './actions';

export const dynamic = 'force-dynamic';

export default async function AdminPage() {
  const { client } = await requireRole(['super_admin']);
  // This query is intentionally executed with the signed-in user's JWT.
  // Admin visibility must be granted by an explicit RLS policy, not by service_role.
  const { data: companies, error } = await client
    .from('company_profiles')
    .select('user_id, company_name, nip, verified')
    .order('company_name', { ascending: true })
    .limit(100);

  return (
    <main className="shell">
      <header className="top"><Link href="/panel" className="logo">e-Mjeshtri</Link></header>
      <section className="auth">
        <h1>Paneli Super Admin</h1>
        <h2>Verifikimi i kompanive</h2>
        {error ? (
          <p role="alert">Lista nuk mund të ngarkohet. Kontrollo politikat e aksesit për Super Admin.</p>
        ) : companies?.length ? (
          <ul>
            {companies.map((company) => (
              <li key={company.user_id}>
                <strong>{company.company_name}</strong>
                {company.nip ? ` — NIPT: ${company.nip}` : ''}
                {' — '}
                <span>{company.verified ? 'E verifikuar' : 'Në pritje të verifikimit'}</span>
                <form action={setCompanyVerification}>
                  <input type="hidden" name="companyId" value={company.user_id} />
                  <input type="hidden" name="verified" value={company.verified ? 'false' : 'true'} />
                  <button type="submit">{company.verified ? 'Çverifiko' : 'Verifiko'}</button>
                </form>
              </li>
            ))}
          </ul>
        ) : <p>Nuk ka kompani të dukshme për këtë llogari.</p>}
        <p className="small">Veprimet kalojnë në server dhe kërkojnë funksionin e autorizuar në Supabase. Derisa funksioni SQL të aktivizohet, kërkesat nuk do të kryhen.</p>
        <Link href="/panel">Kthehu te paneli</Link>
      </section>
    </main>
  );
}
