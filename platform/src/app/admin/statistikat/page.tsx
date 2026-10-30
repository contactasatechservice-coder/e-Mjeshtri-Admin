"use client";
import {useEffect,useState} from "react";
import {getSupabase} from "@/lib/supabase";
type Metric={name:string;value:number|null;error?:string};
const sources=[["Qytetarë","em_candidate_profiles"],["Mjeshtra","em_professional_profiles"],["Kompani","em_companies"],["Vende pune","em_job_postings"],["Aplikime për punë","em_job_applications"],["Kërkesa shërbimi","em_service_requests"],["Njoftime","em_notifications"]] as const;
export default function AdminStatistics(){
 const [metrics,setMetrics]=useState<Metric[]>([]);const [loading,setLoading]=useState(true);const [error,setError]=useState("");
 useEffect(()=>{let live=true;async function load(){try{const db=getSupabase();const {data:{user},error:authError}=await db.auth.getUser();if(authError||user?.app_metadata?.em_admin!==true)throw new Error("Nuk ke autorizim për statistikat.");const results=await Promise.all(sources.map(async ([name,table])=>{const {count,error}=await db.from(table).select("*",{count:"exact",head:true});return {name,value:error?null:count,error:error?.message}}));if(live)setMetrics(results);}catch(e){if(live)setError(e instanceof Error?e.message:"Gabim gjatë ngarkimit.");}finally{if(live)setLoading(false)}}void load();return()=>{live=false}},[]);
 return <main className="admin-jobs"><span className="admin-eyebrow">SUPER ADMIN</span><h1>Statistikat</h1><p>Numërimet e regjistrimeve nga databaza aktive Supabase. Rezultatet varen nga politikat RLS dhe mund të mos përfaqësojnë totalin global nëse qasja është e kufizuar.</p>{loading?<p role="status">Po ngarkohen statistikat...</p>:error?<p role="alert">{error}</p>:<div className="admin-stats">{metrics.map(m=><article className="admin-stat" key={m.name}><span>{m.name}</span><strong>{m.value===null?"—":m.value.toLocaleString("sq-AL")}</strong>{m.error&&<small title={m.error}>Nuk mund të lexohet</small>}</article>)}</div>}<p>Ky është raporti bazë i regjistrimeve, jo ende raport financiar apo analitik i plotë.</p></main>;
}
