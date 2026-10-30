"use client";
import Link from "next/link";
import {useEffect,useState} from "react";
import {usePathname,useRouter} from "next/navigation";
import {getSupabase} from "@/lib/supabase";

const navigation=[
 {title:"Dashboard",href:"/admin",icon:"▦",ready:true},
 {title:"Qytetarët",href:"/admin/qytetaret",icon:"♙",ready:false},
 {title:"Mjeshtrat",href:"/admin/mjeshtrat",icon:"⚒",ready:false},
 {title:"Kompanitë",href:"/admin/kompanite",icon:"▤",ready:true},
 {title:"Vendet e punës",href:"/admin/vendet-e-punes",icon:"▣",ready:false},
 {title:"Kategoritë",href:"/admin/kategorite",icon:"▥",ready:false},
 {title:"Financat",href:"/admin/pagesat",icon:"◈",ready:true},
 {title:"Çmimet dhe paketat",href:"/admin/cmimet",icon:"▧",ready:true},
 {title:"Reklamat",href:"/admin/reklamat",icon:"◉",ready:false},
 {title:"Ankesat",href:"/admin/ankesat",icon:"◇",ready:false},
 {title:"Njoftimet",href:"/admin/njoftimet",icon:"♧",ready:false},
 {title:"Statistikat",href:"/admin/statistikat",icon:"▤",ready:false},
 {title:"Administratorët",href:"/admin/administratoret",icon:"♜",ready:false},
 {title:"Cilësimet",href:"/admin/cilesimet",icon:"⚙",ready:false},
];
export {navigation};
export default function AdminShell({children}:{children:React.ReactNode}){
 const router=useRouter();const pathname=usePathname();
 const [authorized,setAuthorized]=useState(false);const [loading,setLoading]=useState(true);
 const [open,setOpen]=useState(false);
 useEffect(()=>{let alive=true;const db=getSupabase();async function verify(){try{const {data,error}=await db.auth.getUser();if(!alive)return;if(error||data.user?.app_metadata?.em_admin!==true){setAuthorized(false);router.replace("/hyrje?rol=admin");return;}setAuthorized(true);}catch{if(alive)router.replace("/hyrje?rol=admin");}finally{if(alive)setLoading(false);}}void verify();const {data:{subscription}}=db.auth.onAuthStateChange(()=>{void verify();});return()=>{alive=false;subscription.unsubscribe();};},[router]);
 if(loading)return <main className="admin-loading" role="status">Po verifikohet hyrja e administratorit...</main>;
 if(!authorized)return <main className="admin-loading" role="status">Kërkohet hyrja si Super Admin.</main>;
 return <div className="admin-shell">
  <aside className={open?"admin-sidebar open":"admin-sidebar"} aria-label="Menuja Super Admin">
   <Link href="/admin" className="admin-brand" onClick={()=>setOpen(false)}>e-<strong>Mjeshtri</strong><small>SUPER ADMIN</small></Link>
   <nav className="admin-nav">{navigation.map(item=><Link key={item.href} href={item.href} onClick={()=>setOpen(false)} className={pathname===item.href?"active":""}><span aria-hidden="true">{item.icon}</span><span>{item.title}</span>{!item.ready&&<small title="Në zhvillim">Së shpejti</small>}</Link>)}</nav>
   <Link href="/" className="admin-back">← Faqja hyrëse</Link>
  </aside>
  {open&&<button className="admin-overlay" aria-label="Mbyll menunë" onClick={()=>setOpen(false)}/>}
  <div className="admin-main">
   <header className="admin-topbar"><button className="admin-menu-button" onClick={()=>setOpen(v=>!v)} aria-label="Hap menunë" aria-expanded={open}>☰</button><span>Paneli Super Admin</span><button className="admin-signout" onClick={async()=>{await getSupabase().auth.signOut();router.replace("/hyrje?rol=admin");}}>Dil</button></header>
   <div className="admin-content">{children}</div>
  </div>
 </div>;
}
