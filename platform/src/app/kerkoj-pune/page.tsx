"use client";
import {useState,type ChangeEvent,type FormEvent} from "react";
import Link from "next/link";

const MAX_FILE_BYTES=5*1024*1024;
export default function CandidateProfilePage(){
 const [name,setName]=useState("");
 const [headline,setHeadline]=useState("");
 const [city,setCity]=useState("");
 const [summary,setSummary]=useState("");
 const [cv,setCv]=useState<File|null>(null);
 const [notice,setNotice]=useState("");
 function onFile(e:ChangeEvent<HTMLInputElement>){
   const file=e.target.files?.[0]??null;
   setNotice("");
   setCv(null);
   if(!file)return;
   const ext=file.name.split(".").pop()?.toLowerCase();
   if(!["pdf","doc","docx"].includes(ext??"")){setNotice("Lejohen vetëm PDF, DOC dhe DOCX.");e.target.value="";return;}
   if(file.size===0||file.size>MAX_FILE_BYTES){setNotice("CV-ja duhet të jetë deri në 5 MB dhe jo bosh.");e.target.value="";return;}
   setCv(file);
 }
 function submit(e:FormEvent<HTMLFormElement>){
   e.preventDefault();
   if(name.trim().length<3||headline.trim().length<5||city.trim().length<2||summary.trim().length<30){
     setNotice("Plotëso emrin, profesionin, qytetin dhe përshkrimin (të paktën 30 karaktere).");return;
   }
   if(!cv){setNotice("Zgjidh CV-në në format PDF, DOC ose DOCX.");return;}
   setNotice("Të dhënat u kontrolluan në pajisjen tënde. Profili dhe CV-ja NUK janë ruajtur ose dërguar në server. Aktivizimi kërkon ruajtje private dhe kontrolle autorizimi.");
 }
 return <main className="section form-page">
   <span className="eyebrow">Kandidatët</span>
   <h1>Kërkoj punë</h1>
   <p>Krijo profilin e kandidatit dhe përgatit CV-në. Ky është formular demonstrues; CV-ja nuk ngarkohet dhe profili nuk bëhet publik.</p>
   <form className="listing-form" onSubmit={submit}>
     <label>Emri dhe mbiemri<input required minLength={3} maxLength={120} autoComplete="name" value={name} onChange={e=>setName(e.target.value)} placeholder="Emri dhe mbiemri"/></label>
     <label>Profesioni ose pozicioni i kërkuar<input required minLength={5} maxLength={160} value={headline} onChange={e=>setHeadline(e.target.value)} placeholder="P.sh. Teknik IT"/></label>
     <label>Qyteti<input required minLength={2} maxLength={80} value={city} onChange={e=>setCity(e.target.value)} placeholder="P.sh. Tiranë"/></label>
     <label>Përvoja dhe aftësitë<textarea required minLength={30} maxLength={3000} rows={6} value={summary} onChange={e=>setSummary(e.target.value)} placeholder="Përshkruaj eksperiencën, aftësitë dhe llojin e punës që kërkon."/></label>
     <label>CV (PDF, DOC ose DOCX, deri në 5 MB)<input required type="file" accept=".pdf,.doc,.docx,application/pdf,application/msword,application/vnd.openxmlformats-officedocument.wordprocessingml.document" onChange={onFile}/></label>
     {cv&&<p className="form-note">CV e zgjedhur: {cv.name} ({(cv.size/1024/1024).toFixed(2)} MB). Nuk është ngarkuar.</p>}
     <button type="submit" className="button primary">Kontrollo profilin</button>
     <p role="status" aria-live="polite">{notice}</p>
   </form>
   <p><Link href="/regjistrohu" style={{textDecoration:"underline"}}>Krijo llogari</Link> për të qenë gati kur aplikimet të aktivizohen.</p>
 </main>;
}
