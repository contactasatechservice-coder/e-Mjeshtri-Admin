"use client";
import {useEffect,useState} from "react";
import Link from "next/link";
import {getSupabase} from "@/lib/supabase";
type Profile={user_id:string;display_name:string;profession:string;city:string;description:string|null};
export default function Services(){
 const [items,setItems]=useState<Profile[]>([]);const [loading,setLoading]=useState(true);const [notice,setNotice]=useState("");const [query,setQuery]=useState("");
 useEffect(()=>{let active=true;async function load(){try{const {data,error}=await getSupabase().from("em_professional_profiles").select("user_id,display_name,profession,city,description").eq("is_public",true).order("created_at",{ascending:false}).limit(100);if(error)throw error;if(active)setItems(data??[]);}catch{if(active)setNotice("Profilet nuk u ngarkuan.");}finally{if(active)setLoading(false);}}void load();return()=>{active=false};},[]);
 const filtered=items.filter(x=>(x.display_name+" "+x.profession+" "+x.city).toLocaleLowerCase("sq").includes(query.toLocaleLowerCase("sq")));
 return <main className="section"><span className="eyebrow">Profesionistë të regjistruar</span><h1>Gjej mjeshtrin e duhur</h1><p>Shfleto profilet publike të mjeshtrave në platformë.</p><label>Kërko profesion ose qytet<input value={query} onChange={e=>setQuery(e.target.value)} placeholder="P.sh. Hidraulik, Durrës" style={{display:"block",width:"100%",maxWidth:520,padding:12,marginTop:8}}/></label>{loading?<p>Po ngarkohen profilet...</p>:notice?<p role="status">{notice}</p>:filtered.length===0?<p>Nuk ka ende profile publike që përputhen me kërkimin.</p>:<div className="grid" style={{marginTop:24}}>{filtered.map(x=><article className="tile" key={x.user_id}><h2>{x.display_name}</h2><p><strong>{x.profession}</strong> · {x.city}</p><p>{x.description||"Profesionist i regjistruar në e-Mjeshtri."}</p></article>)}</div>}<p style={{marginTop:24}}><Link href="/profili-mjeshtrit">Krijo ose përditëso profilin tim si mjeshtër</Link></p></main>;
}