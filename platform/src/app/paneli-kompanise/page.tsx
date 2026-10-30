import Link from "next/link";

const features=[
 {title:"Shpalljet e punës",description:"Krijo, rishiko dhe mbyll shpalljet. Statuset draft, në shqyrtim, publikuar dhe mbyllur do të lidhen me databazën."},
 {title:"Aplikimet e kandidatëve",description:"Shiko vetëm aplikimet për shpalljet e kompanisë ku ke autorizim. CV-të duhet të mbeten private."},
 {title:"Intervistat",description:"Organizo kandidatët sipas fazave: në shqyrtim, listë e shkurtër, intervistë dhe ofertë."},
 {title:"Anëtarët e kompanisë",description:"Pronari do të menaxhojë rolet e menaxherit dhe rekrutuesit, me leje të kufizuara."}
];
export default function CompanyDashboard(){
 return <main className="section">
  <span className="eyebrow">Për kompanitë</span>
  <h1>Paneli i kompanisë</h1>
  <p>Menaxho punësimin nga një vend. Kjo faqe paraqet strukturën e panelit; nuk shfaq të dhëna reale dhe nuk lejon ende leximin e CV-ve.</p>
  <div className="actions"><Link className="button primary" href="/publiko-vend-pune">Përgatit një shpallje</Link><Link className="button secondary" href="/hyrje">Hyr në llogari</Link></div>
  <section className="section" aria-label="Funksionet e panelit">
   <div className="grid">{features.map(f=><article key={f.title} className="tile"><h2 style={{fontSize:21}}>{f.title}</h2><p>{f.description}</p><p className="form-note">Në zhvillim — nuk ka të dhëna reale.</p></article>)}</div>
  </section>
  <section className="tile" style={{maxWidth:760}}>
   <h2 style={{fontSize:23}}>Siguria e aplikimeve</h2>
   <p>Kur të aktivizohet databaza, vetëm pronari dhe anëtarët e autorizuar të kompanisë do të mund të lexojnë aplikimet e saj. CV-të nuk do të publikohen në profile publike.</p>
  </section>
 </main>;
}
