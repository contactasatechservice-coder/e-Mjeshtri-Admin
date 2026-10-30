"use client";
import {useState,type FormEvent} from "react";
import Link from "next/link";
import {useRouter} from "next/navigation";
import {getSupabase} from "@/lib/supabase";
type Role="citizen"|"company"|"admin";
const roles:{id:Role;title:string;description:string}[]=[
 {id:"citizen",title:"Qytetar / Mjeshtër",description:"Kërko shërbime, ofro punën tënde dhe apliko për punë."},
 {id:"company",title:"Kompani",description:"Menaxho shpalljet, kandidatët dhe reklamat."}
];
export default function Login(){
 const router=useRouter();
 const [role,setRole]=useState<Role>("citizen");
 const [email,setEmail]=useState("");
 const [password,setPassword]=useState("");
 const [notice,setNotice]=useState("");
 const [busy,setBusy]=useState(false);
 async function submit(e:FormEvent<HTMLFormElement>){
  e.preventDefault();setBusy(true);setNotice("");
  try{
   const db=getSupabase();
   const {data,error}=await db.auth.signInWithPassword({email,password});
   if(error||!data.user){setNotice(error?.message??"Hyrja dështoi.");return;}
   if(role==="admin"){
    const {data:verified,error:verifyError}=await db.auth.getUser();
    if(verifyError||verified.user?.app_metadata?.em_admin!==true){
     await db.auth.signOut();setNotice("Kjo llogari nuk ka autorizim Super Admin.");return;
    }
    router.replace("/admin/cmimet");return;
   }
   if(role==="company"){
    const {data:memberships,error:memberError}=await db.from("em_company_memberships").select("business_id").eq("user_id",data.user.id).eq("status","active").limit(1);
    if(memberError){setNotice("Nuk u verifikua anëtarësia e kompanisë. Provo përsëri.");return;}
    if(!memberships?.length){setNotice("Nuk ke ende kompani aktive. Regjistro kompaninë për të hyrë në panel.");return;}
    router.replace("/paneli-kompanise");return;
   }
   router.replace("/");
  }catch{setNotice("Lidhja me shërbimin e hyrjes nuk është e disponueshme.");}
  finally{setBusy(false);}
 }
 return <main style={{maxWidth:560,margin:"0 auto",padding:"42px 18px 70px"}}>
  <h1 style={{marginBottom:8}}>Mirë se erdhe në e-Mjeshtri</h1>
  <p style={{color:"#53657a",marginBottom:24}}>Zgjidh mënyrën e hyrjes në platformë.</p>
  {role!=="admin"?<div style={{display:"grid",gridTemplateColumns:"repeat(2,minmax(0,1fr))",gap:12,marginBottom:26}}>
   {roles.map(item=><button key={item.id} type="button" aria-pressed={role===item.id} onClick={()=>{setRole(item.id);setNotice("");}} style={{border:role===item.id?"2px solid #0c4d91":"1px solid #cbd5e1",borderRadius:16,padding:"18px 12px",textAlign:"left",background:role===item.id?"#eef6ff":"#fff",color:"#123c66",cursor:"pointer",minHeight:120}}>
    <strong style={{display:"block",fontSize:17,marginBottom:8}}>{item.title}</strong>
    <span style={{display:"block",fontSize:13,lineHeight:1.45}}>{item.description}</span>
   </button>)}
  </div>:<button type="button" className="button secondary" style={{marginBottom:24}} onClick={()=>{setRole("citizen");setNotice("");}}>← Kthehu te hyrja e përdoruesve</button>}
  <h2 style={{fontSize:23,marginBottom:18}}>{role==="admin"?"Hyr si Super Admin":role==="company"?"Hyr si Kompani":"Hyr si Qytetar / Mjeshtër"}</h2>
  <form onSubmit={submit} style={{display:"grid",gap:16}}>
   <label>Email<input autoComplete="email" required type="email" value={email} onChange={e=>setEmail(e.target.value)} style={{display:"block",padding:13,width:"100%",marginTop:6,borderRadius:9}}/></label>
   <label>Fjalëkalimi<input autoComplete="current-password" required type="password" value={password} onChange={e=>setPassword(e.target.value)} style={{display:"block",padding:13,width:"100%",marginTop:6,borderRadius:9}}/></label>
   <button disabled={busy} type="submit" className="button primary" style={{width:"100%",minHeight:50}}>{busy?"Duke hyrë...":"Hyr"}</button>
  </form>
  <p role="status" aria-live="polite" style={{marginTop:14}}>{notice}</p>
  {role!=="admin"&&<p style={{marginTop:14}}>Nuk ke llogari? <Link href="/regjistrohu">Krijo llogari</Link>{role==="company"&&<> · <Link href="/regjistro-kompani">Regjistro kompaninë</Link></>}</p>}
  <div style={{borderTop:"1px solid #d5dce5",marginTop:32,paddingTop:22,textAlign:"center"}}>
   {role!=="admin"?<button type="button" onClick={()=>{setRole("admin");setNotice("");}} style={{border:"1px solid #0c4d91",background:"transparent",color:"#0c4d91",borderRadius:10,padding:"12px 20px",fontWeight:700,cursor:"pointer"}}>Hyr si Super Admin</button>:<p style={{color:"#53657a",fontSize:13}}>Hyrja është e rezervuar vetëm për administratorët e autorizuar.</p>}
  </div>
 </main>;
}
