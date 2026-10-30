import Link from 'next/link';
import { requireRole } from '@/lib/server/require-role';
import { LogoutButton } from '../logout-button';
import { CitizenCategoryIcon } from './category-icon';

const categories = [
  { name: 'Hidraulik', icon: '🔧' },
  { name: 'Elektricist', icon: '⚡' },
  { name: 'Lyerje', icon: '🖌️' },
  { name: 'Ndërtim', icon: '🏗️' },
  { name: 'Klimatizim', icon: '❄️' },
  { name: 'Pastrim', icon: '🧹' },
];

export default async function CitizenDashboard() {
  const { user, client } = await requireRole(['citizen']);
  const [requestsResult, applicationsResult] = await Promise.all([
    client.from('service_requests').select('id,title,status,created_at').eq('citizen_id', user.id).order('created_at', { ascending: false }).limit(5),
    client.from('job_applications').select('id,status,created_at').eq('applicant_id', user.id).order('created_at', { ascending: false }).limit(5),
  ]);
  const requests = requestsResult.data ?? [];
  const applications = applicationsResult.data ?? [];
  const firstName = typeof user.user_metadata?.full_name === 'string'
    ? user.user_metadata.full_name.trim().split(/\s+/)[0] : '';
  return (
    <main className="citizen-page">
      <header className="citizen-topbar">
        <Link href="/" className="citizen-brand">e-<span>Mjeshtri</span></Link>
        <nav aria-label="Navigimi i qytetarit" className="citizen-desktop-nav">
          <Link href="/" className="citizen-home-link">Ballina</Link>
          <Link href="/oferta-pune" className="citizen-home-link">Oferta pune</Link>
          <LogoutButton />
        </nav>
        <details className="citizen-mobile-menu"><summary aria-label="Hap menunë">☰ Menu</summary><nav aria-label="Menuja e qytetarit"><Link href="/panel/qytetar">Paneli im</Link><Link href="/kerko">Shërbimet</Link><Link href="/oferta-pune">Oferta pune</Link><Link href="/">Ballina</Link></nav></details>
      </header>
      <div className="citizen-container">
        <section className="citizen-hero">
          <div className="citizen-hero-copy">
            <span className="citizen-eyebrow">PANELI QYTETAR</span>
            <h1>{firstName ? `Mirë se erdhe, ${firstName}!` : 'Mirë se erdhe!'}</h1>
            <p>Gjithçka që të duhet për të gjetur profesionistë të besueshëm dhe mundësi pune, në një vend.</p>
            <form action="/kerko" className="citizen-search">
              <label htmlFor="citizen-search-input" className="sr-only">Kërko shërbime</label>
              <input id="citizen-search-input" name="q" placeholder="Çfarë shërbimi po kërkon?" />
              <button type="submit">Kërko →</button>
            </form>
          </div>
          <div className="citizen-hero-art" aria-hidden="true"><span>🏠</span><span>🛠️</span></div>
        </section>
        <section className="citizen-section">
          <div className="citizen-section-head"><div><span className="citizen-overline">SHËRBIMET</span><h2>Gjej një profesionist</h2></div><Link href="/kerko">Shiko të gjitha →</Link></div>
          <div className="citizen-category-grid">
            {categories.map(category => (
              <Link key={category.name} href={`/kerko?q=${encodeURIComponent(category.name)}`} className="citizen-category">
                <span aria-hidden="true" className="citizen-modern-icon"><CitizenCategoryIcon name={category.name} /></span><strong>{category.name}</strong>
              </Link>
            ))}
          </div>
        </section>
        <section className="citizen-section">
          <div className="citizen-section-head"><div><span className="citizen-overline">ZBULO MUNDËSI</span><h2>Çfarë dëshiron të bësh?</h2></div></div>
          <div className="citizen-feature-grid">
            <article className="citizen-feature"><span className="citizen-feature-icon">🔎</span><h3>Kërko shërbime</h3><p>Shfleto shërbimet e publikuara dhe gjej profesionistin e duhur për punën tënde.</p><Link href="/kerko">Gjej mjeshtër →</Link></article>
            <article className="citizen-feature"><span className="citizen-feature-icon orange">💼</span><h3>Oferta pune</h3><p>Eksploro vendet e punës të publikuara nga kompani të ndryshme.</p><Link href="/oferta-pune">Shiko ofertat →</Link></article>
          </div>
        </section>
        <section className="citizen-section" aria-labelledby="citizen-activity-title">
          <div className="citizen-section-head"><div><span className="citizen-overline">AKTIVITETI YT</span><h2 id="citizen-activity-title">Kërkesat dhe aplikimet</h2></div></div>
          <div className="citizen-feature-grid">
            <article className="citizen-feature"><span className="citizen-feature-icon">📋</span><h3>Kërkesat e mia</h3>
              {requestsResult.error ? <p>Nuk u arritën të ngarkohen kërkesat.</p> : requests.length === 0 ? <p>Nuk ke ende kërkesa për shërbime.</p> : <ul className="citizen-activity-list">{requests.map(request => <li key={request.id}><strong>{request.title}</strong><span>{request.status}</span></li>)}</ul>}
            </article>
            <article className="citizen-feature"><span className="citizen-feature-icon orange">💼</span><h3>Aplikimet e mia</h3>
              {applicationsResult.error ? <p>Nuk u arritën të ngarkohen aplikimet.</p> : applications.length === 0 ? <p>Nuk ke ende aplikime për punë.</p> : <ul className="citizen-activity-list">{applications.map(application => <li key={application.id}><strong>Aplikim pune</strong><span>{application.status}</span></li>)}</ul>}
              <Link href="/oferta-pune">Shiko ofertat →</Link>
            </article>
          </div>
        </section>
      </div>
    </main>
  );
}
