"use client";
import {useEffect,useMemo,useState} from "react";
import Link from "next/link";
import {getSupabase} from "@/lib/supabase";

type Job={id:string;title:string;city:string;description:string;employment_type:string;salary_min:number|null;salary_max:number|null;currency:string;published_at:string|null};
type LoadState="loading"|"ready"|"unavailable";
export default function JobsPage(){
 const [jobs,setJobs]=useState<Job[]>([]);
 const [state,setState]=useState<LoadState>("loading");
 const [query,setQuery]=useState("");
 const [city,setCity]=useState("");
 const [applying,setApplying]=useState<string|null>(null);
 const [applicationNotice,setApplicationNotice]=useState<Record<string,string>>({});
 async function apply(jobId:string){
  setApplying(jobId);
  try{
   const supabase=getSupabase();
   const {data:{user},error:authError}=await supabase.auth.getUser();
   if(authError||!user){setApplicationNotice(n=>({...n,[jobId]:"Hyr në llogari për të aplikuar."}));return;}
   const {data:profile,error:profileError}=await supabase.from("em_candidate_profiles").select("user_id").eq("user_id",user.id).maybeSingle();
   if(profileError||!profile){setApplicationNotice(n=>({...n,[jobId]:"Krijo fillimisht profilin Kërkoj punë."}));return;}
   const {error}=await supabase.from("em_job_applications").insert({job_id:jobId,candidate_id:user.id,status:"submitted"});
   if(error){setApplicationNotice(n=>({...n,[jobId]:error.code==="23505"?"Ke aplikuar më parë për këtë pozicion.":"Aplikimi nuk u ruajt: "+error.message}));return;}
   setApplicationNotice(n=>({...n,[jobId]:"Aplikimi u regjistrua me sukses, pa CV. Kompania mund ta shohë aplikimin."}));
  }catch{setApplicationNotice(n=>({...n,[jobId]:"Nuk u realizua aplikimi. Provo përsëri."}));}
  finally{setApplying(null);}
 }
 useEffect(()=>{
  let active=true;
  async function load(){
   try{
    const {data,error}=await getSupabase().from("em_job_postings")
      .select("id,title,city,description,employment_type,salary_min,salary_max,currency,published_at")
      .eq("status","published").order("published_at",{ascending:false}).limit(100);
    if(!active)return;
    if(error){setState("unavailable");return;}
    setJobs((data??[]) as Job[]);setState("ready");
   }catch{if(active)setState("unavailable");}
  }
  void load();return()=>{active=false;};
 },[]);
 const filtered=useMemo(()=>jobs.filter(j=>
  (j.title+" "+j.description).toLocaleLowerCase("sq").includes(query.trim().toLocaleLowerCase("sq")) &&
  j.city.toLocaleLowerCase("sq").includes(city.trim().toLocaleLowerCase("sq"))
 ),[jobs,query,city]);
 return <main className="section">
  <span className="eyebrow">Punësim në Shqipëri</span><h1>Vende pune</h1>
  <p>Shpalljet e publikuara nga kompanitë. Nuk përdoren vende pune të sajuara.</p>
  <div className="filters">
   <label>Kërko pozicionin<input value={query} onChange={e=>setQuery(e.target.value)} placeholder="P.sh. Ekonomist, IT, shitës"/></label>
   <label>Qyteti<input value={city} onChange={e=>setCity(e.target.value)} placeholder="P.sh. Tiranë"/></label>
  </div>
  {state==="loading"&&<p role="status">Po ngarkohen shpalljet...</p>}
  {state==="unavailable"&&<section className="tile" role="status"><h2 style={{fontSize:22}}>Shpalljet nuk janë ende të disponueshme</h2><p>Moduli i punësimit në databazë nuk është aktivizuar ose nuk është i aksesueshëm. Nuk mund të shfaqim shpallje reale tani.</p></section>}
  {state==="ready"&&filtered.length===0&&<p role="status">Nuk ka shpallje të publikuara që përputhen me kërkimin.</p>}
  {state==="ready"&&filtered.length>0&&<div className="grid">{filtered.map(j=><article className="tile" key={j.id}>
   <h2 style={{fontSize:22}}>{j.title}</h2><p><strong>{j.city}</strong> · {j.employment_type}</p>
   {(j.salary_min!==null||j.salary_max!==null)&&<p>Paga: {j.salary_min??"—"} – {j.salary_max??"—"} {j.currency}</p>}
   <p>{j.description.length>230?j.description.slice(0,230)+"…":j.description}</p>
   <p className="form-note">Aplikimi fillestar bëhet pa CV. Dokumentet private do të aktivizohen më vonë.</p><button type="button" className="button primary" disabled={applying===j.id} onClick={()=>void apply(j.id)}>{applying===j.id?"Po aplikohet...":"Apliko për këtë pozicion"}</button>{applicationNotice[j.id]&&<p role="status">{applicationNotice[j.id]}</p>}
  </article>)}</div>}
  <div className="actions"><Link className="button secondary" href="/kerkoj-pune">Krijo profilin Kërkoj punë</Link><Link className="button primary" href="/publiko-vend-pune">Përgatit shpallje</Link></div>
 </main>;
}
