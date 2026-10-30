"use client";
import {useEffect,useState,type FormEvent} from "react";
import Link from "next/link";
import {useRouter} from "next/navigation";
import {getSupabase} from "@/lib/supabase";
type Kind="individual"|"company";
export default function Register(){
 const router=useRouter();const [kind,setKind]=useState<Kind>("individual");const [email,setEmail]=useState("");const [password,setPassword]=useState("");const [confirm,setConfirm]=useState("");const [showPassword,setShowPassword]=useState(false);const [notice,setNotice]=useState("");const [busy,setBusy]=useState(false);
 useEffect(()=>{if(new URLSearchParams(window.location.search).get("lloji")==="kompani")setKind("company");},[]);
 async function submit(e:FormEvent<HTMLFormElement>){
  e.preventDefault();if(password!==confirm){setNotice("Fjalëkalimet nuk përputhen.");return;}setBusy(true);setNotice("");
  try{const db=getSupabase();const {data,error}=await db.auth.signUp({email:email.trim(),password});if(error){setNotice(error.message);return;}
   if(data.session&&data.user){
    if(kind==="company"){router.replace("/regjistro-kompani");return;}
    router.replace("/");return;
   }
   setNotice(kind==="company"?"Llogaria u regjistrua. Konfirmo emailin nëse kërkohet, hyr në llogari dhe plotëso kërkesën e kompanisë. Aksesi aktivizohet vetëm pas miratimit.":"Llogaria u regjistrua. Konfirmo emailin nëse kërkohet nga shërbimi dhe pastaj hyr në platformë.");
  }catch{setNotice("Regjistrimi nuk u përfundua. Provo përsëri.");}finally{setBusy(false);}
 }
 const inputStyle={display:"block" as const,width:"100%",padding:"15px 16px",border:"1px solid #d8dee8",borderRadius:13,background:"#fff",fontSize:16,marginTop:8};
 return <main style={{maxWidth:540,margin:"0 auto",padding:"30px 18px 60px"}}>
  <div style={{textAlign:"center",marginBottom:24}}><h1 style={{fontSize:30,color:"#0c4d91",marginBottom:8}}>Krijo llogari</h1><p style={{color:"#64748b"}}>Zgjidh si dëshiron të regjistrohesh në e-Mjeshtri.</p></div>
  <div role="tablist" aria-label="Lloji i regjistrimit" style={{display:"grid",gridTemplateColumns:"1.5fr 1fr",gap:4,padding:5,background:"#edf0f5",borderRadius:15,marginBottom:20}}>
   {([{id:"individual",label:"Qytetar / Mjeshtër"},{id:"company",label:"Kompani"}] as const).map(t=><button key={t.id} type="button" role="tab" aria-selected={kind===t.id} onClick={()=>{setKind(t.id);setNotice("");}} style={{padding:"14px 6px",border:0,borderRadius:11,background:kind===t.id?"white":"transparent",boxShadow:kind===t.id?"0 2px 7px rgba(20,35,55,.1)":"none",color:kind===t.id?"#0c4d91":"#536174",fontWeight:700,fontSize:14,cursor:"pointer"}}>{t.label}</button>)}
  </div>
  <div style={{padding:"15px 17px",background:kind==="company"?"#fff7ed":"#eef6ff",borderRadius:12,marginBottom:24,color:"#26445e",fontSize:14,lineHeight:1.6}}>
   {kind==="company"?"Kompanitë krijojnë fillimisht llogarinë, më pas dërgojnë të dhënat e biznesit. Paneli i kompanisë hapet vetëm pasi Super Admin ta miratojë kërkesën.":"Qytetarët dhe mjeshtrat regjistrohen falas dhe përdorin platformën pa miratim administrativ. Mund të kërkohet konfirmim emaili për sigurinë e llogarisë."}
  </div>
  <form onSubmit={submit} style={{display:"grid",gap:17}}>
   <label style={{fontWeight:600}}>Adresa e emailit<input required type="email" autoComplete="email" value={email} onChange={e=>setEmail(e.target.value)} placeholder="email@shembull.al" style={inputStyle}/></label>
   <label style={{fontWeight:600}}>Fjalëkalimi<div style={{position:"relative"}}><input required minLength={8} type={showPassword?"text":"password"} autoComplete="new-password" value={password} onChange={e=>setPassword(e.target.value)} placeholder="Të paktën 8 karaktere" style={{...inputStyle,paddingRight:70}}/><button type="button" onClick={()=>setShowPassword(v=>!v)} style={{position:"absolute",right:10,top:"50%",transform:"translateY(-40%)",border:0,background:"transparent",color:"#0c4d91",fontWeight:700,cursor:"pointer"}}>{showPassword?"Fshih":"Shfaq"}</button></div></label>
   <label style={{fontWeight:600}}>Konfirmo fjalëkalimin<input required minLength={8} type={showPassword?"text":"password"} autoComplete="new-password" value={confirm} onChange={e=>setConfirm(e.target.value)} style={inputStyle}/></label>
   <button disabled={busy} className="button primary" type="submit" style={{width:"100%",minHeight:52,borderRadius:12,fontWeight:700}}>{busy?"Duke u regjistruar...":kind==="company"?"Vazhdo me regjistrimin e kompanisë":"Krijo llogari falas"}</button>
  </form>
  <p role="status" aria-live="polite" style={{marginTop:15}}>{notice}</p>
  {kind==="company"&&<p style={{fontSize:14,color:"#536174"}}>Ke krijuar llogarinë? <Link href="/regjistro-kompani">Dërgo kërkesën e kompanisë</Link></p>}
  <p style={{textAlign:"center",marginTop:24}}>Ke llogari? <Link href="/hyrje">Hyr në platformë</Link></p>
 </main>;
}
