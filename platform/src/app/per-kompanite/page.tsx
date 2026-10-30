import Link from "next/link";
const jobPlans=[
 {name:"Shpallje standarde",price:"990 Lekë",details:"1 shpallje për 30 ditë"},
 {name:"Shpallje e sponsorizuar",price:"1,990 Lekë",details:"1 shpallje për 30 ditë, me pozicionim të veçantë"},
 {name:"Paketë kompanie",price:"3,990 Lekë",details:"Deri në 5 shpallje për 30 ditë"}
];
const advertising=[
 {name:"Banner standard",price:"Nga 1,490 Lekë",details:"7 ditë shfaqje, sipas hapësirës"},
 {name:"Fushatë e personalizuar",price:"Me ofertë",details:"Pozicionim, kohëzgjatje dhe krijimtari sipas marrëveshjes"}
];
export default function ForCompanies(){
 return <main className="section"><span className="eyebrow">Për bizneset</span><h1>Shpallje pune dhe reklama</h1>
 <p>Regjistrimi i kompanisë është falas. Kandidatët, mjeshtrat dhe përdoruesit nuk paguajnë abonim për të përdorur platformën.</p>
 <p className="form-note">Çmimet më poshtë janë propozime për planifikim, jo oferta përfundimtare. Pagesat dhe fushatat nuk aktivizohen automatikisht.</p>
 <section className="section"><h2>Shpallje pune</h2><div className="grid">{jobPlans.map(p=><article className="tile" key={p.name}><h3>{p.name}</h3><p><strong>{p.price}</strong></p><p>{p.details}</p></article>)}</div></section>
 <section className="section"><h2>Reklamim në platformë</h2><div className="grid">{advertising.map(p=><article className="tile" key={p.name}><h3>{p.name}</h3><p><strong>{p.price}</strong></p><p>{p.details}</p></article>)}</div></section>
 <section className="section"><h2>Si do të funksionojë pagesa?</h2><p>Kompania krijon një draft shpalljeje ose kërkesë reklame, zgjedh paketën dhe merr udhëzimet e pagesës. Administratori verifikon pagesën përpara aktivizimit. Nuk kërkohen të dhëna të kartës bankare në këtë faqe.</p><div className="actions"><Link className="button primary" href="/regjistro-kompani">Regjistro kompaninë</Link><Link className="button secondary" href="/paneli-kompanise">Paneli i kompanisë</Link></div></section>
 </main>;
}
