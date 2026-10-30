"use client";
import Link from "next/link";
import {useState} from "react";
import {useRouter} from "next/navigation";
import {getSupabase} from "@/lib/supabase";
export default function SiteHeader(){
 const [open,setOpen]=useState(false);
 const [checking,setChecking]=useState(false);
 const router=useRouter();
 async function publish(){
  setOpen(false);setChecking(true);
  try{
   const db=getSupabase();
   const {data:{user},error}=await db.auth.getUser();
   if(error||!user){router.push("/hyrje?redirect=%2Fpubliko-pune");return;}
   const {data:membership,error:memberError}=await db.from("em_company_memberships").select("business_id").eq("user_id",user.id).eq("status","active").limit(1);
   if(!memberError&&membership?.length){router.push("/publiko-vend-pune");return;}
   router.push("/publiko-pune");
  }catch{router.push("/hyrje?redirect=%2Fpubliko-pune");}
  finally{setChecking(false);}
 }
 return <header className="nav topbar">
  <Link href="/" className="logo" aria-label="e-Mjeshtri - Kryefaqja"><span className="brand-mark" aria-hidden="true">⌂<span>🔧</span></span><span><em>e-</em>Mjeshtri</span></Link>
  <button type="button" className="mobile-menu" onClick={()=>setOpen(!open)} aria-expanded={open} aria-label="Hap menunë">☰</button>
  <nav className={open?"open":""} aria-label="Navigimi kryesor">
   <Link href="/" onClick={()=>setOpen(false)}>Kryefaqja</Link>
   <Link href="/pune" onClick={()=>setOpen(false)}>Punë</Link>
   <Link href="/sherbime" onClick={()=>setOpen(false)}>Mjeshtra</Link>
   <Link href="/sherbime" onClick={()=>setOpen(false)}>Kategoritë</Link>
   <Link href="/#si-funksionon" onClick={()=>setOpen(false)}>Si funksionon</Link>
   <Link href="/hyrje" onClick={()=>setOpen(false)}>Hyr</Link>
   <button className="nav-join" type="button" onClick={()=>void publish()} disabled={checking} style={{cursor:"pointer",border:0}}>{checking?"Duke kontrolluar...":"＋ Publiko një punë"}</button>
  </nav>
 </header>;
}
