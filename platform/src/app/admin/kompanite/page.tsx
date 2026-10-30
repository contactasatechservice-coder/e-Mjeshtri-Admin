"use client";
import {useEffect,useState} from "react";
import Link from "next/link";
import {getSupabase} from "@/lib/supabase";
type Request={id:string;company_name:string;registration_number:string;city:string;contact_email:string;representative_name:string|null;phone:string|null;address:string|null;industry:string|null;website:string|null;description:string|null;status:string;created_at:string};
export default function ReviewCompanies(){
 const [requests,setRequests]=useState<Request[]>([]);
 const [notice,setNotice]=useState("");
 const [loading,setLoading]=useState(true);
 const [busy,setBusy]=useState<string|null>(null);
 const [authorized,setAuthorized]=useState(false);
 async function refresh(){
  try{
   const db=getSupabase();
   const {data:{user},error:authError}=await db.auth.getUser();
   if(authError||!user){setNotice("Identifikohu si administrator.");return;}
   if(user.app_metadata?.em_admin!==true){setNotice("Nuk ke leje administratori për verifikimin e kompanive.");return;}
   setAuthorized(true);
   const {data,error}=await db.from("em_company_registration_requests")
     .select("id,company_name,registration_number,city,contact_email,representative_name,phone,address,industry,website,description,status,created_at")
     .eq("status","pending").order("created_at",{ascending:true}).limit(100);
   if(error)throw error;
   setRequests(data??[]);
  }catch{setNotice("Nuk u ngarkuan kërkesat. Kontrollo autorizimet.");}
  finally{setLoading(false);}
 }
 useEffect(()=>{void refresh();},[]);
 async function review(id:string,approve:boolean){
  if(!confirm(approve?"Miraton këtë kompani dhe cakton kërkuesin si pronar?":"Refuzon këtë kërkesë?"))return;
  setBusy(id);setNotice("");
  try{
   const {error}=await getSupabase().rpc("em_review_company_request",{p_request_id:id,p_approve:approve});
   if(error){setNotice("Veprimi nuk u krye: "+error.message);return;}
   setNotice(approve?"Kompania u miratua dhe pronari u caktua.":"Kërkesa u refuzua.");
   await refresh();
  }catch{setNotice("Veprimi dështoi. Nuk është konfirmuar asnjë ndryshim.");}
  finally{setBusy(null);}
 }
 return <main className="section"><span className="eyebrow">Administrimi</span><h1>Verifikimi i kompanive</h1>
  <p>Vetëm administratori i autorizuar mund të miratojë ose refuzojë kërkesat. Miratimi krijon kompaninë dhe anëtarësimin e pronarit në një transaksion.</p>
  {loading&&<p role="status">Po kontrollohen autorizimet...</p>}
  {notice&&<p role="status">{notice}</p>}
  {authorized&&<section className="section"><h2>Kërkesa në pritje ({requests.length})</h2>
   {requests.length===0?<p>Nuk ka kërkesa në pritje.</p>:<div className="grid">{requests.map(r=><article className="tile" key={r.id}>
    <h3>{r.company_name}</h3><p>NIPT: {r.registration_number}</p><p>{r.city} · {r.contact_email}</p><p>Përfaqësuesi: {r.representative_name||"—"}</p><p>Telefon: {r.phone||"—"}</p><p>Adresa: {r.address||"—"}</p><p>Aktiviteti: {r.industry||"—"}</p>{r.website&&<p>Website: {r.website}</p>}{r.description&&<p>{r.description}</p>}
    <p>Dërguar: {new Date(r.created_at).toLocaleDateString("sq-AL")}</p>
    <div className="actions"><button type="button" className="button primary" disabled={busy!==null} onClick={()=>void review(r.id,true)}>Mirato</button>
    <button type="button" className="button secondary" disabled={busy!==null} onClick={()=>void review(r.id,false)}>Refuzo</button></div>
   </article>)}</div>}
  </section>}
  <Link href="/paneli-kompanise">Paneli i kompanisë</Link>
 </main>;
}
