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
   <p className="form-note">Aplikimi online do të aktivizohet pas verifikimit të CV-ve dhe autorizimeve.</p>
  </article>)}</div>}
  <div className="actions"><Link className="button secondary" href="/kerkoj-pune">Krijo profilin Kërkoj punë</Link><Link className="button primary" href="/publiko-vend-pune">Përgatit shpallje</Link></div>
 </main>;
}
