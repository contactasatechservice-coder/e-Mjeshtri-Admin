"use client";
import {useState,type FormEvent} from "react";
import Link from "next/link";
import {useRouter} from "next/navigation";
import {getSupabase} from "@/lib/supabase";
type Role="citizen"|"company"|"admin";
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
    if(!memberships?.length){const {data:requests}=await db.from("em_company_registration_requests").select("status").eq("requester_id",data.user.id).order("created_at",{ascending:false}).limit(1);setNotice(requests?.[0]?.status==="pending"?"Kompania jote është në pritje të verifikimit nga Super Admin.":requests?.[0]?.status==="rejected"?"Kërkesa e kompanisë është refuzuar. Kontakto administratorin.":"Nuk ke kompani të miratuar. Dërgo kërkesën e regjistrimit të kompanisë.");return;}
    router.replace("/paneli-kompanise");return;
   }
   const next=new URLSearchParams(window.location.search).get("redirect");
   const allowed=["/publiko-pune","/kerkesat-e-mia","/profili-mjeshtrit","/paneli-mjeshtrit","/mesazhet"];
   if(next&&allowed.includes(next)){router.replace(next);return;}
   const accountType=data.user.user_metadata?.account_type;
   router.replace(accountType==="master"?"/paneli-mjeshtrit":"/kerkesat-e-mia");
  }catch{setNotice("Lidhja me shërbimin e hyrjes nuk është e disponueshme.");}
  finally{setBusy(false);}
 }
 const [showPassword,setShowPassword]=useState(false);
 const tabs:{id:Role;label:string}[]=[{id:"citizen",label:"Qytetar / Mjeshtër"},{id:"company",label:"Kompani"}];
 const inputStyle={display:"block" as const,width:"100%",padding:"15px 16px",border:"1px solid #d8dee8",borderRadius:13,background:"#fff",fontSize:16,color:"#172b45",outlineColor:"#0e5393"};
 return <main style={{maxWidth:540,margin:"0 auto",padding:"28px 18px 56px"}}>
  <div style={{textAlign:"center",marginBottom:28}}>
   <div style={{display:"inline-flex",alignItems:"center",justifyContent:"center",width:58,height:58,borderRadius:18,background:"#0c4d91",color:"#fff",fontWeight:800,fontSize:29,marginBottom:12}}>e</div>
   <h1 style={{fontSize:30,margin:"0 0 5px",color:"#0c4d91",lineHeight:1.2}}>Hyr në e-Mjeshtri</h1>
   <p style={{color:"#64748b",fontSize:14,margin:0}}>Zgjidh llojin e llogarisë</p>
  </div>
  <div role="tablist" aria-label="Lloji i hyrjes" style={{display:"grid",gridTemplateColumns:"1.5fr 1fr",padding:5,gap:3,background:"#edf0f5",borderRadius:15,marginBottom:30}}>
   {tabs.map(t=><button key={t.id} type="button" role="tab" aria-selected={role===t.id} onClick={()=>{setRole(t.id);setNotice("");}} style={{padding:"13px 5px",border:0,borderRadius:11,background:role===t.id?"#fff":"transparent",boxShadow:role===t.id?"0 2px 7px rgba(20,35,55,.10)":"none",fontSize:13,fontWeight:role===t.id?750:500,color:role===t.id?"#0c4d91":"#536174",cursor:"pointer"}}>{t.label}</button>)}
  </div>
  <form onSubmit={submit} style={{display:"grid",gap:18}}>
   <label style={{fontSize:15,fontWeight:600,color:"#22364f"}}>Adresa e emailit
    <input autoComplete="email" required type="email" placeholder="Shkruaj emailin" value={email} onChange={e=>setEmail(e.target.value)} style={{...inputStyle,marginTop:9}}/>
   </label>
   <label style={{fontSize:15,fontWeight:600,color:"#22364f"}}>Fjalëkalimi
    <div style={{position:"relative",marginTop:9}}>
     <input autoComplete="current-password" required type={showPassword?"text":"password"} placeholder="Shkruaj fjalëkalimin" value={password} onChange={e=>setPassword(e.target.value)} style={{...inputStyle,paddingRight:70}}/>
     <button type="button" aria-label={showPassword?"Fshih fjalëkalimin":"Shfaq fjalëkalimin"} onClick={()=>setShowPassword(v=>!v)} style={{position:"absolute",right:8,top:"50%",transform:"translateY(-50%)",background:"transparent",border:0,padding:"8px 6px",color:"#0c4d91",fontWeight:600,fontSize:12,cursor:"pointer"}}>{showPassword?"Fshih":"Shfaq"}</button>
    </div>
   </label>
   <button disabled={busy} type="submit" className="button primary" style={{width:"100%",minHeight:52,borderRadius:12,fontWeight:750,fontSize:16,marginTop:5}}>{busy?"Duke hyrë...":"Hyr në llogari"}</button>
  </form>
  <p role="status" aria-live="polite" style={{marginTop:14,color:"#a02e2e",fontSize:14}}>{notice}</p>
  {role!=="admin"&&<div style={{textAlign:"center",marginTop:16,fontSize:14,color:"#596779"}}>Nuk ke llogari? <Link href={role==="company"?"/regjistrohu?lloji=kompani":"/regjistrohu"} style={{fontWeight:700,color:"#0c4d91"}}>Krijo llogari</Link>{role==="company"&&<p><Link href="/regjistro-kompani">Regjistro kompaninë</Link></p>}</div>}
  <div style={{borderTop:"1px solid #e2e8f0",marginTop:32,paddingTop:22,textAlign:"center"}}>
   {role!=="admin"?<button type="button" onClick={()=>{setRole("admin");setNotice("");}} style={{width:"100%",padding:"14px 16px",border:"1.5px solid #0c4d91",borderRadius:12,background:"#fff",color:"#0c4d91",fontSize:15,fontWeight:700,cursor:"pointer"}}>Hyr si Super Admin</button>:<button type="button" onClick={()=>{setRole("citizen");setNotice("");}} style={{width:"100%",padding:"14px 16px",border:"1px solid #cbd5e1",borderRadius:12,background:"#fff",color:"#0c4d91",fontWeight:700,cursor:"pointer"}}>Kthehu te hyrja e përdoruesve</button>}
  </div>
 </main>;
}
