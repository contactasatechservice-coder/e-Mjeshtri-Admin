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
 const [jobs,setJobs]=useState<{id:string;title:string;status:string}[]>([]);
 const [applications,setApplications]=useState<{id:string;job_id:string;status:string;created_at:string}[]>([]);
 const [dataNotice,setDataNotice]=useState("");
 const [changing,setChanging]=useState<string|null>(null);
 async function changeStatus(id:string,status:"published"|"closed"){
  setChanging(id);setDataNotice("");
  try{
   const db=getSupabase();
   const {data:{user},error:authError}=await db.auth.getUser();
   if(authError||!user){setDataNotice("Identifikohu përsëri.");return;}
   const update=status==="published"?{status,published_at:new Date().toISOString()}:{status};
   const {data,error}=await db.from("em_job_postings").update(update).eq("id",id).select("id,status");
   if(error){setDataNotice("Ndryshimi dështoi: "+error.message);return;}
   if(!data?.length){setDataNotice("Nuk ke autorizim për këtë shpallje.");return;}
   setJobs(old=>old.map(j=>j.id===id?{...j,status}:j));
   setDataNotice(status==="published"?"Shpallja u publikua.":"Shpallja u mbyll.");
  }catch{setDataNotice("Nuk u realizua ndryshimi.");}
  finally{setChanging(null);}
 }
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
    if(authorized.length){
      const ids=authorized.map(m=>m.business_id);
      const {data:jobRows,error:jobError}=await supabase.from("em_job_postings")
        .select("id,title,status").in("business_id",ids).order("created_at",{ascending:false}).limit(100);
      if(!active)return;
      if(jobError){setDataNotice("Nuk u ngarkuan shpalljet.");return;}
      setJobs(jobRows??[]);
      const jobIds=(jobRows??[]).map(j=>j.id);
      if(jobIds.length){
        const {data:appRows,error:appError}=await supabase.from("em_job_applications")
          .select("id,job_id,status,created_at").in("job_id",jobIds).order("created_at",{ascending:false}).limit(100);
        if(!active)return;
        if(appError)setDataNotice("Nuk u ngarkuan aplikimet.");
        else setApplications(appRows??[]);
      }
    }
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
   <p className="form-note">Autorizimi i shfaqjes kontrollohet nga anëtarësimet. Të dhënat lexohen nga Supabase sipas politikave RLS. Publikimi dhe mbyllja e shpalljeve janë të disponueshme për anëtarët e autorizuar. CV-të mbeten në zhvillim.</p>
   <div className="actions"><Link className="button primary" href="/publiko-vend-pune">Përgatit një shpallje</Link><Link className="button secondary" href="/per-kompanite">Çmimet dhe reklamat</Link><Link className="button secondary" href="/pagesat-kompanive">Pagesat bankare</Link></div>
   <p className="form-note">Publikimi kërkon konfirmim të pagesës nga administratori. Draftet mbeten falas.</p>
   {dataNotice&&<p role="alert">{dataNotice}</p>}
   <section className="section"><h2>Shpalljet ({jobs.length})</h2>
    {jobs.length===0?<p>Nuk ka shpallje të regjistruara.</p>:<div className="grid">{jobs.map(j=><article className="tile" key={j.id}><h3>{j.title}</h3><p>Statusi: {j.status}</p><p>Aplikime: {applications.filter(a=>a.job_id===j.id).length}</p><div className="actions">{j.status==="draft"&&<button type="button" className="button primary" disabled={changing!==null} onClick={()=>void changeStatus(j.id,"published")}>Publiko</button>}{j.status==="published"&&<button type="button" className="button secondary" disabled={changing!==null} onClick={()=>void changeStatus(j.id,"closed")}>Mbyll shpalljen</button>}</div></article>)}</div>}
   </section>
   <section className="section"><h2>Aplikimet e fundit ({applications.length})</h2>
    {applications.length===0?<p>Nuk ka aplikime për t’u shfaqur.</p>:<div className="grid">{applications.map(a=><article className="tile" key={a.id}><p>Pozicioni: {jobs.find(j=>j.id===a.job_id)?.title??"—"}</p><p>Statusi: {a.status}</p><p>Data: {new Date(a.created_at).toLocaleDateString("sq-AL")}</p></article>)}</div>}
   </section>
   <section className="section" aria-label="Funksionet e panelit"><div className="grid">{features.map(f=><article key={f.title} className="tile"><h2 style={{fontSize:21}}>{f.title}</h2><p>{f.description}</p><p className="form-note">Në zhvillim — nuk shfaqen të dhëna personale.</p></article>)}</div></section>
  </>}
 </main>;
}
