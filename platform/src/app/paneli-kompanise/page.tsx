"use client";
import {useEffect,useState} from "react";
import Link from "next/link";
import {getSupabase} from "@/lib/supabase";

type State="checking"|"guest"|"unauthorized"|"authorized"|"error";
type Membership={business_id:string;role:string;status:string};
const features=[
 {title:"Shpalljet e punës",description:"Krijo dhe menaxho shpalljet e kompanisë."},
 {title:"Aplikimet e kandidatëve",description:"Aplikimet dhe CV-të do të jenë të dukshme vetëm për rekrutuesit e autorizuar."},
 {title:"Intervistat",description:"Menaxho procesin e intervistave dhe ofertave."},
 {title:"Anëtarët e kompanisë",description:"Menaxho aksesin sipas rolit të secilit anëtar."}
];
export default function CompanyDashboard(){
 const [state,setState]=useState<State>("checking");
 const [memberships,setMemberships]=useState<Membership[]>([]);
 const [notice,setNotice]=useState("");
 useEffect(()=>{
  let active=true;
  async function check(){
   try{
    const supabase=getSupabase();
    const {data:{user},error:authError}=await supabase.auth.getUser();
    if(!active)return;
    if(authError||!user){setState("guest");return;}
    const {data,error}=await supabase.from("em_company_memberships")
     .select("business_id,role,status")
     .eq("user_id",user.id).eq("status","active");
    if(!active)return;
    if(error){
     setNotice("Nuk mund të verifikohen autorizimet e kompanisë. Moduli i databazës mund të mos jetë aktivizuar ende.");
     setState("error");return;
    }
    const authorized=(data??[]).filter((m:Membership)=>["owner","manager","recruiter"].includes(m.role));
    setMemberships(authorized);
    setState(authorized.length?"authorized":"unauthorized");
   }catch{
    if(active){setNotice("Lidhja me shërbimin e identifikimit nuk është e disponueshme.");setState("error");}
   }
  }
  void check();
  return()=>{active=false;};
 },[]);
 return <main className="section">
  <span className="eyebrow">Për kompanitë</span><h1>Paneli i kompanisë</h1>
  {state==="checking"&&<p role="status">Po kontrollohen hyrja dhe autorizimet...</p>}
  {state==="guest"&&<section className="tile"><h2>Hyrja e nevojshme</h2><p>Duhet të identifikohesh për të hyrë në panelin e kompanisë.</p><Link className="button primary" href="/hyrje">Hyr në llogari</Link></section>}
  {state==="unauthorized"&&<section className="tile"><h2>Akses i kufizuar</h2><p>Nuk ke një anëtarësim aktiv si pronar, menaxher ose rekrutues në një kompani.</p><p>Kontakto pronarin e kompanisë për autorizim.</p></section>}
  {state==="error"&&<p role="alert">{notice}</p>}
  {state==="authorized"&&<>
   <p>Ke akses në {memberships.length} {memberships.length===1?"kompani":"kompani"} me rol menaxhimi ose rekrutimi.</p>
   <p className="form-note">Autorizimi i shfaqjes kontrollohet nga anëtarësimet. Veprimet e databazës kërkojnë gjithashtu politika RLS dhe nuk janë aktivizuar ende.</p>
   <div className="actions"><Link className="button primary" href="/publiko-vend-pune">Përgatit një shpallje</Link></div>
   <section className="section" aria-label="Funksionet e panelit"><div className="grid">{features.map(f=><article key={f.title} className="tile"><h2 style={{fontSize:21}}>{f.title}</h2><p>{f.description}</p><p className="form-note">Në zhvillim — nuk shfaqen të dhëna personale.</p></article>)}</div></section>
  </>}
 </main>;
}
