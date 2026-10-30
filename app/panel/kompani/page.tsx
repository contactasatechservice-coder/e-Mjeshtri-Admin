import Link from 'next/link';
import { requireRole } from '@/lib/server/require-role';

export const dynamic = 'force-dynamic';

export default async function RolePage() {
  const { user, client } = await requireRole(['company']);
  const [companyResult, jobsResult] = await Promise.all([
    client.from('company_profiles').select('company_name, verified').eq('user_id', user.id).maybeSingle(),
    client.from('job_posts').select('id, title, city, status, created_at').eq('company_id', user.id).order('created_at', { ascending: false }).limit(30),
  ]);
  if (companyResult.error || jobsResult.error) {
    throw new Error('Nuk u ngarkuan te dhenat e kompanise');
  }
  const company = companyResult.data;
  const jobs = jobsResult.data ?? [];
  return (
    <main className="shell">
      <header className="top"><Link href="/panel" className="logo">e-Mjeshtri</Link></header>
      <section className="auth">
        <h1>{company?.company_name || 'Paneli Kompani'}</h1>
        <p className="small">Statusi i verifikimit: <strong>{company?.verified ? 'E verifikuar' : 'Në pritje të verifikimit'}</strong></p>
        {!company?.verified && <p>Publikimi i vendeve të punës aktivizohet vetëm pas verifikimit nga administratori.</p>}
        <h2>Vendet e punës ({jobs.length})</h2>
        {jobs.length === 0 ? <p>Ende nuk ka njoftime pune të regjistruara.</p> : (
          <ul>
            {jobs.map((job) => (
              <li key={job.id}>
                <strong>{job.title}</strong> — {job.city || 'Pa qytet'} ({job.status})
              </li>
            ))}
          </ul>
        )}
        <Link href="/panel">Kthehu te paneli</Link>
      </section>
    </main>
  );
}
