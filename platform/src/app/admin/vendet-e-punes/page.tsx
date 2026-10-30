"use client";
import {useEffect,useMemo,useState} from "react";
import {getSupabase} from "@/lib/supabase";
type Job={id:string;title:string;city:string|null;status:string;employment_type:string|null;business_id:string;created_at:string};
export default function AdminJobs(){
 const [jobs,setJobs]=useState<Job[]>([]);const [query,setQuery]=useState("");const [status,setStatus]=useState("all");const [loading,setLoading]=useState(true);const [error,setError]=useState("");
 useEffect(()=>{let live=true;async function load(){try{
 const db=getSupabase();const {data:{user},error:authError}=await db.auth.getUser();
 if(authError||user?.app_metadata?.em_admin!==true)throw new Error("Nuk ke autorizim për këtë faqe.");
 const {data,error}=await db.from("em_job_postings").select("id,title,city,status,employment_type,business_id,created_at").order("created_at",{ascending:false}).limit(250);
 if(error)throw error;if(live)setJobs((data??[]) as Job[]);
 }catch(e){if(live)setError(e instanceof Error?e.message:"Nuk u ngarkuan shpalljet.");}finally{if(live)setLoading(false);}}void load();return()=>{live=false}},[]);
 const filtered=useMemo(()=>jobs.filter(j=>(status==="all"||j.status===status)&&[j.title,j.city,j.business_id].join(" ").toLocaleLowerCase("sq").includes(query.toLocaleLowerCase("sq"))),[jobs,query,status]);
 const statuses=Array.from(new Set(jobs.map(j=>j.status)));
 return <main className="admin-jobs"><span className="admin-eyebrow">SUPER ADMIN</span><h1>Vendet e punës</h1><p>Shiko dhe kërko shpalljet e kompanive. Ky modul është aktualisht vetëm për lexim, për të shmangur ndryshime pa një proces moderimi të audituar.</p>
 <div className="admin-jobs-filters"><label>Kërko shpallje<input value={query} onChange={e=>setQuery(e.target.value)} placeholder="Titulli, qyteti ose ID e kompanisë"/></label><label>Statusi<select value={status} onChange={e=>setStatus(e.target.value)}><option value="all">Të gjitha</option>{statuses.map(s=><option key={s} value={s}>{s}</option>)}</select></label></div>
 {loading?<p role="status">Po ngarkohen shpalljet...</p>:error?<p role="alert">{error}</p>:<><p role="status">{filtered.length} shpallje të shfaqura (deri në 250 më të fundit)</p><div className="admin-jobs-list">{filtered.map(j=><article key={j.id}><div><h2>{j.title}</h2><p>{j.city||"Qyteti i pacaktuar"} · {j.employment_type||"Lloji i pacaktuar"}</p><small>Kompania: {j.business_id}</small></div><div><span className="admin-job-status">{j.status}</span><small>{new Date(j.created_at).toLocaleDateString("sq-AL")}</small></div></article>)}{filtered.length===0&&<p>Nuk u gjet asnjë shpallje për filtrat e zgjedhur.</p>}</div></>}
 </main>;
}
