"use client";
import {useState,type FormEvent} from "react";
import {getSupabase} from "@/lib/supabase";
type Kind="job"|"service";
const categories=["Hidraulik","Elektricist","Ndërtim & Riparime","Lyerje","Pastrim","Kondicionerë","Tjetër"];
export default function ListingForm({kind}:{kind:Kind}){
 const [title,setTitle]=useState("");const [category,setCategory]=useState(categories[0]);const [city,setCity]=useState("");const [description,setDescription]=useState("");const [price,setPrice]=useState("");const [notice,setNotice]=useState("");const [saving,setSaving]=useState(false);
 async function submit(e:FormEvent<HTMLFormElement>){
  e.preventDefault();setNotice("");
  if(title.trim().length<5||description.trim().length<20||city.trim().length<2){setNotice("Plotëso titullin (min. 5), qytetin dhe përshkrimin (min. 20 karaktere).");return;}
  if(price!==""&&(!Number.isFinite(Number(price))||Number(price)<0)){setNotice("Buxheti duhet të jetë numër pozitiv.");return;}
  setSaving(true);
  try{
   const db=getSupabase();const {data:{user},error:authError}=await db.auth.getUser();
   if(authError||!user){setNotice("Duhet të hysh në llogari për të publikuar.");return;}
   if(kind!=="job"){setNotice("Ky lloj publikimi nuk është aktivizuar ende.");return;}
   const {error}=await db.from("em_service_requests").insert({customer_id:user.id,title:title.trim(),category,city:city.trim(),description:description.trim(),budget_all:price===""?null:Number(price),status:"open"});
   if(error)throw error;
   setNotice("Kërkesa u publikua me sukses dhe është e dukshme për mjeshtrat.");
   setTitle("");setCity("");setDescription("");setPrice("");setCategory(categories[0]);
  }catch(e){setNotice("Publikimi dështoi: "+(e instanceof Error?e.message:"Provo përsëri."));}
  finally{setSaving(false);}
 }
 return <form onSubmit={submit} className="listing-form"><label>Titulli<input required minLength={5} maxLength={160} value={title} onChange={e=>setTitle(e.target.value)} placeholder={kind==="job"?"P.sh. Riparim rubineti":"P.sh. Riparime hidraulike"}/></label><label>Kategoria<select value={category} onChange={e=>setCategory(e.target.value)}>{categories.map(x=><option key={x}>{x}</option>)}</select></label><label>Qyteti<input required minLength={2} maxLength={80} value={city} onChange={e=>setCity(e.target.value)} placeholder="P.sh. Tiranë"/></label><label>{kind==="job"?"Buxheti i përafërt (Lekë, opsional)":"Çmimi fillestar (Lekë, opsional)"}<input type="number" min="0" step="1" value={price} onChange={e=>setPrice(e.target.value)} placeholder="P.sh. 5000"/></label><label>Përshkrimi<textarea required minLength={20} maxLength={3000} rows={6} value={description} onChange={e=>setDescription(e.target.value)} placeholder="Përshkruaj qartë detajet..."/></label><button className="button primary" disabled={saving} type="submit">{saving?"Po publikohet...":"Publiko kërkesën"}</button><p role="status" aria-live="polite">{notice}</p></form>;
}
