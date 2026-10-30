"use client";
import {useEffect,useState} from "react";
import {getSupabase} from "@/lib/supabase";
type Notification={id:string;title:string;body:string;read_at:string|null;created_at:string};
export default function Notifications(){const [items,setItems]=useState<Notification[]>([]);const [notice,setNotice]=useState("");
useEffect(()=>{let active=true;async function load(){try{const db=getSupabase();const {data:{user}}=await db.auth.getUser();if(!user){if(active)setNotice("Identifikohu për të parë njoftimet.");return;}const {data,error}=await db.from("em_notifications").select("id,title,body,read_at,created_at").order("created_at",{ascending:false}).limit(100);if(error)throw error;if(active)setItems(data??[]);}catch{if(active)setNotice("Nuk u ngarkuan njoftimet.");}}void load();return()=>{active=false};},[]);
async function markRead(id:string){const {data,error}=await getSupabase().from("em_notifications").update({read_at:new Date().toISOString()}).eq("id",id).select("id,read_at");if(error||!data?.length){setNotice("Njoftimi nuk u përditësua.");return;}setItems(items=>items.map(n=>n.id===id?{...n,read_at:data[0].read_at}:n));}
return <main className="section"><h1>Njoftimet</h1><p role="status">{notice}</p>{items.length===0&&<p>Nuk ka njoftime.</p>}<div className="grid">{items.map(n=><article className="tile" key={n.id}><h2>{n.title}</h2><p>{n.body}</p><p>{new Date(n.created_at).toLocaleDateString("sq-AL")}</p>{!n.read_at&&<button type="button" className="button secondary" onClick={()=>void markRead(n.id)}>Shëno si lexuar</button>}</article>)}</div></main>;
}