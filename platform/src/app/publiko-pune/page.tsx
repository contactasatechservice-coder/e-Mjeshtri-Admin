import Link from "next/link";
import ListingForm from "@/components/listing-form";

export default function Page() {
  return (
    <main className="section form-page">
      <span className="eyebrow">Kërkesë për shërbim</span>
      <h1>Publiko një kërkesë për profesionist</h1>
      <p>Ke nevojë për hidraulik, elektricist apo një profesionist tjetër? Përshkruaj punën dhe buxhetin e përafërt.</p>
      <p><strong>Je kompani dhe kërkon punonjës?</strong> Shpalljet e punësimit janë të ndryshme nga kërkesat për shërbime. Moduli i vendeve të punës do të aktivizohet pasi të përfundojnë databaza dhe kontrollet e sigurisë.</p>
      <p>Ky formular është ende demonstrues: të dhënat nuk publikohen dhe nuk ruhen.</p>
      <ListingForm kind="job" />
      <p><Link href="/regjistrohu">Krijo llogari</Link> ose <Link href="/hyrje">hyr në llogarinë tënde</Link>.</p>
    </main>
  );
}
