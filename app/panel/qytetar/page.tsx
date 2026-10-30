import Link from 'next/link';
import { requireRole } from '@/lib/server/require-role';
import { LogoutButton } from '../logout-button';

export default async function RolePage() {
  await requireRole(['citizen']);
  return (
    <main className="shell">
      <header className="top"><Link href="/" className="logo">e-Mjeshtri</Link><LogoutButton /></header>
      <section className="auth">
        <h1>Paneli Qytetar</h1>
        <p className="small">Gjej profesionistë për shërbimet që të duhen dhe shiko mundësitë e punësimit.</p>
        <form action="/kerko"><label className="field">Kërko shërbime<input name="q" placeholder="p.sh. hidraulik" /></label><button type="submit" className="action">Kërko</button></form>
        <nav aria-label="Veprimet e qytetarit"><p><Link className="action" href="/kerko">Shiko shërbimet</Link></p><p><Link className="ghost" href="/oferta-pune">Oferta pune</Link></p></nav>
        <p className="small">Mesazhet dhe aplikimet personale janë ende në zhvillim.</p>
        <Link href="/">Kthehu te ballina</Link>
      </section>
    </main>
  );
}
