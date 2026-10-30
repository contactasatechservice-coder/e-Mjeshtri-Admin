import Link from "next/link";
export default function MessagesPage() {
  return (
    <main className="section">
      <h1>Mesazhet</h1>
      <p>Mesazhet private do të jenë të disponueshme pasi të aktivizohet databaza dhe hyrja e përdoruesve.</p>
      <p>Aktualisht nuk ka biseda të ruajtura.</p>
      <Link href="/pune">Shiko punët</Link>
    </main>
  );
}
