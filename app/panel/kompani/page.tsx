import Link from 'next/link';
import { requireRole } from '@/lib/server/require-role';

export default async function RolePage() {
  await requireRole(['company']);
  return (
    <main className="shell">
      <header className="top"><Link href="/panel" className="logo">e-Mjeshtri</Link></header>
      <section className="auth">
        <h1>Paneli Kompani</h1>
        <p className="small">Aksesi në këtë faqe verifikohet në server. Modulet e këtij paneli janë ende në zhvillim.</p>
        <Link href="/panel">Kthehu te paneli</Link>
      </section>
    </main>
  );
}
