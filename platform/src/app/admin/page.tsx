"use client";
import Link from "next/link";
import {useEffect,useState} from "react";
import {getSupabase} from "@/lib/supabase";
type Summary={companies:number|null;pendingCompanies:number|null;pendingPayments:number|null;jobs:number|null};
export default function AdminDashboard(){
 const [stats,setStats]=useState<Summary>({companies:null,pendingCompanies:null,pendingPayments:null,jobs:null});
 const [error,setError]=useState("");
 useEffect(()=>{let live=true;async function load(){try{const db=getSupabase();const {data:{user}}=await db.auth.getUser();if(user?.app_metadata?.em_admin!==true)return;const requests=[
 db.from("em_companies").select("*",{count:"exact",head:true}),
 db.from("em_company_registration_requests").select("*",{count:"exact",head:true}).eq("status","pending"),
 db.from("em_company_commercial_orders").select("*",{count:"exact",head:true}).eq("status","submitted"),
 db.from("em_job_postings").select("*",{count:"exact",head:true})
 ];const result=await Promise.all(requests);if(!live)return;setStats({companies:result[0].error?null:result[0].count,pendingCompanies:result[1].error?null:result[1].count,pendingPayments:result[2].error?null:result[2].count,jobs:result[3].error?null:result[3].count});if(result.some(x=>x.error))setError("Disa statistika nuk janë të disponueshme për këtë llogari.");}catch{if(live)setError("Statistikat nuk u ngarkuan.");}}void load();return()=>{live=false};},[]);
 const cards=[{label:"Kompanitë",value:stats.companies},{label:"Kompani në pritje",value:stats.pendingCompanies},{label:"Pagesa për verifikim",value:stats.pendingPayments},{label:"Shpallje pune",value:stats.jobs}];
 return <main className="admin-dashboard"><div className="admin-welcome"><span className="admin-eyebrow">PËRMBLEDHJE</span><h1>Mirë se erdhe në Super Admin</h1><p>Menaxho platformën e-Mjeshtri nga një panel i vetëm.</p></div>
 <section aria-label="Statistikat" className="admin-stats">{cards.map(c=><article className="admin-stat" key={c.label}><span>{c.label}</span><strong>{c.value===null?"—":c.value.toLocaleString("sq-AL")}</strong></article>)}</section>
 {error&&<p role="status" className="admin-notice">{error}</p>}
 <section className="admin-quick"><div className="admin-section-heading"><h2>Veprime të shpejta</h2><p>Menaxho kërkesat dhe pagesat nga një vend.</p></div><div className="admin-quick-grid"><Link href="/admin/kompanite"><span>Kompanitë</span><strong>Shqyrto regjistrimet <span aria-hidden="true">→</span></strong></Link><Link href="/admin/pagesat"><span>Financat</span><strong>Verifiko pagesat <span aria-hidden="true">→</span></strong></Link><Link href="/admin/cmimet"><span>Paketat</span><strong>Menaxho çmimet <span aria-hidden="true">→</span></strong></Link></div></section>
 </main>;
}
