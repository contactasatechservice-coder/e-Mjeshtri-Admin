"use client";
import {useEffect,useState} from "react";
import {getSupabase} from "@/lib/supabase";
type Complaint={id:string;reporter_id:string;subject:string;details:string;status:string;created_at:string};
export default function AdminComplaints(){
 const [rows,setRows]=useState<Complaint[]>([]),[error,setError]=useState(""),[busy,setBusy]=useState<string|null>(null),[authorized,setAuthorized]=useState(false);
 async function load(){const db=getSupabase();const {data:{user}}=await db.auth.getUser();if(user?.app_metadata?.em_admin!==true){setError("Nuk ke autorizim.");return;}setAuthorized(true);const {data,error}=await db.from("em_complaints").select("id,reporter_id,subject,details,status,created_at").order("created_at",{ascending:false}).limit(200);if(error)setError(error.message);else setRows((data??[]) as Complaint[]);}
 useEffect(()=>{void load()},[]);
 async function update(c:Complaint,status:string){if(!confirm("Ndrysho statusin e ankesës?"))return;setBusy(c.id);const {error}=await getSupabase().from("em_complaints").update({status,updated_at:new Date().toISOString()}).eq("id",c.id);if(error)setError(error.message);else await load();setBusy(null);}
 return <main className="admin-jobs"><span className="admin-eyebrow">SUPER ADMIN</span><h1>Ankesat</h1><p>Regjistri i ankesave të platformës. Statuset menaxhohen nga Super Admin.</p>{error&&<p role="alert">{error}</p>}{authorized&&<div className="admin-jobs-list">{rows.map(c=><article key={c.id}><div><h2>{c.subject}</h2><p>{c.details}</p><small>Raportuesi: {c.reporter_id} · {new Date(c.created_at).toLocaleDateString("sq-AL")}</small></div><div><label>Statusi<select value={c.status} disabled={busy!==null} onChange={e=>void update(c,e.target.value)}><option value="open">Hapur</option><option value="in_review">Në shqyrtim</option><option value="resolved">Zgjidhur</option><option value="rejected">Refuzuar</option></select></label></div></article>)}{rows.length===0&&<p>Ende nuk ka ankesa.</p>}</div>}</main>;
}
