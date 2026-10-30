import Link from "next/link";

const roles = [
  { name: "Qytetar", href: "/qytetar", left: "3.3%", top: "46.8%", width: "45.6%", height: "23.6%" },
  { name: "Mjeshtër", href: "/mjeshter", left: "51.3%", top: "46.8%", width: "45.6%", height: "23.6%" },
  { name: "Kompani", href: "/per-kompanite", left: "3.3%", top: "71.6%", width: "45.6%", height: "23.8%" },
  { name: "Admin", href: "/hyrje?rol=admin", left: "51.3%", top: "71.6%", width: "45.6%", height: "23.8%" },
];

export default function Welcome() {
  return (
    <main className="welcome-fixed">
      <div className="welcome-fixed-art">
        <img
          src="/images/faqja-kryesore.png"
          alt="Mirë se vini në e-Mjeshtri. Zgjidh rolin tënd: Qytetar, Mjeshtër, Kompani ose Admin."
          width={1024}
          height={1536}
          className="welcome-fixed-image"
        />
        {roles.map((role) => (
          <Link
            key={role.name}
            href={role.href}
            className="welcome-fixed-hotspot"
            aria-label={`Vazhdo si ${role.name}`}
            title={`Vazhdo si ${role.name}`}
            style={{ left: role.left, top: role.top, width: role.width, height: role.height }}
          >
            <span className="welcome-fixed-sr">Vazhdo si {role.name}</span>
          </Link>
        ))}
      </div>
    </main>
  );
}
