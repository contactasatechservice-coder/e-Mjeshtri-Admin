import Link from 'next/link';
import { requireRole } from '@/lib/server/require-role';
import { changeApplicationStatus } from './actions';

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
  const jobIds = (jobsResult.data ?? []).map(job => job.id);
  const applicationsResult = jobIds.length ? await client.from('job_applications').select('id,job_id,applicant_id,status,cover_letter,created_at').in('job_id', jobIds).order('created_at', { ascending: false }).limit(100) : { data: [], error: null };
  const applications = applicationsResult.data ?? [];
  const applicantIds = [...new Set(applications.map(application => application.applicant_id))];
  const applicantsResult = applicantIds.length ? await client.from('profiles').select('id,full_name,city').in('id',applicantIds) : {data:[],error:null};
  const applicantById = new Map((applicantsResult.data ?? []).map(applicant => [applicant.id,applicant]));
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
        <h2>Aplikimet e kandidatëve ({applications.length})</h2>
        {applicationsResult.error ? <p role="alert">Aplikimet nuk u ngarkuan. Kontrollo lejet e aksesit.</p> : applications.length === 0 ? <p>Ende nuk ka aplikime për ofertat e tua.</p> : <ul className="company-applications">{applications.map(application => <li key={application.id}><strong>{jobs.find(job => job.id === application.job_id)?.title ?? 'Ofertë pune'}</strong><p>Statusi: {application.status}</p>{application.cover_letter && <p>{application.cover_letter}</p>}<small>Kandidati: {applicantById.get(application.applicant_id)?.full_name || 'Kandidat'}{applicantById.get(application.applicant_id)?.city ? ` · ${applicantById.get(application.applicant_id)?.city}` : ''}</small>{['applied','reviewing','interview'].includes(application.status) && <form action={changeApplicationStatus} className="company-status-form"><input type="hidden" name="application_id" value={application.id}/><label htmlFor={`status-${application.id}`}>Ndrysho statusin</label><select id={`status-${application.id}`} name="status" required defaultValue=""><option value="" disabled>Zgjidh</option><option value="reviewing">Në shqyrtim</option><option value="interview">Intervistë</option><option value="accepted">Prano</option><option value="rejected">Refuzo</option></select><button type="submit">Ruaj</button></form>}</li>)}</ul>}
        <Link href="/panel">Kthehu te paneli</Link>
      </section>
    </main>
  );
}
