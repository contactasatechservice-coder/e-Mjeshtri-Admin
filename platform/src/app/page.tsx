import Link from "next/link";

const roles = [
  { name: "Qytetar", description: "Gjej profesionistë për shërbimet e tua.", href: "/qytetar", icon: "♟", photo: "citizen" },
  { name: "Mjeshtër", description: "Regjistrohu si profesionist dhe gjej më shumë punë.", href: "/mjeshter", icon: "⚒", photo: "craftsman" },
  { name: "Kompani", description: "Posto vende pune dhe gjej profesionistë të kualifikuar.", href: "/per-kompanite", icon: "▥", photo: "company" },
  { name: "Admin", description: "Hyr si administrator për menaxhimin e platformës.", href: "/hyrje?rol=admin", icon: "⚙", photo: "admin" },
];

export default function Welcome() {
  return (
    <main className="welcome-rebuilt">
      <header className="welcome-heading">
        <div className="welcome-brand" aria-label="e-Mjeshtri">
          <span className="welcome-brand-symbol" aria-hidden="true">⌂<span>🔧</span></span>
          <div><em>e-</em>Mjeshtri</div>
        </div>
        <h1>Mirë se vini në e-Mjeshtri!</h1>
        <p>Platforma që të lidh me profesionistët<br className="desktop-break" /> dhe mundësitë e punës.</p>
      </header>
      <section className="welcome-selection" aria-labelledby="welcome-roles-title">
        <div className="welcome-rule" />
        <h2 id="welcome-roles-title">Zgjidh rolin tënd</h2>
        <p>Vazhdo duke zgjedhur rolin që të përfaqëson.</p>
        <div className="welcome-cards">
          {roles.map(role => (
            <Link key={role.name} className="welcome-card" href={role.href} aria-label={`Vazhdo si ${role.name}`}>
              <div className={`welcome-card-photo welcome-photo-${role.photo}`} aria-hidden="true" />
              <div className="welcome-card-info">
                <span className="welcome-card-icon" aria-hidden="true">{role.icon}</span>
                <span className="welcome-card-copy"><strong>{role.name}</strong><span>{role.description}</span></span>
                <span className="welcome-card-arrow" aria-hidden="true">›</span>
              </div>
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}
