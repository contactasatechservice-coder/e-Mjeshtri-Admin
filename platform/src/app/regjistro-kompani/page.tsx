"use client";
import {useEffect,useState,type FormEvent} from "react";
import Link from "next/link";
import {getSupabase} from "@/lib/supabase";

type Request={id:string;company_name:string;registration_number:string;city:string;status:string;created_at:string};
export default function RegisterCompany(){
 const [name,setName]=useState("");
 const [nipt,setNipt]=useState("");
 const [city,setCity]=useState("");
 const [email,setEmail]=useState("");
 const [representative,setRepresentative]=useState("");const [phone,setPhone]=useState("");const [address,setAddress]=useState("");const [industry,setIndustry]=useState("");const [website,setWebsite]=useState("");const [description,setDescription]=useState("");
 useEffect(()=>{try{const draft=JSON.parse(sessionStorage.getItem("em_company_registration_draft")||"null");if(draft){setName(draft.company_name||"");setNipt(draft.registration_number||"");setCity(draft.city||"");setEmail(draft.contact_email||"");setRepresentative(draft.representative_name||"");setPhone(draft.phone||"");setAddress(draft.address||"");setIndustry(draft.industry||"");setWebsite(draft.website||"");setDescription(draft.description||"");}}catch{}},[]);
 const [requests,setRequests]=useState<Request[]>([]);
 const [notice,setNotice]=useState("");
 const [saving,setSaving]=useState(false);
 async function refresh(){
  try{
   const db=getSupabase();
   const {data:{user}}=await db.auth.getUser();
   if(!user)return;
   const {data,error}=await db.from("em_company_registration_requests")
    .select("id,company_name,registration_number,city,status,created_at")
    .eq("requester_id",user.id).order("created_at",{ascending:false}).limit(20);
   if(error)throw error;
   setRequests(data??[]);
  }catch{setNotice("Nuk u ngarkua historiku i kërkesave.");}
 }
 useEffect(()=>{void refresh();},[]);
 async function submit(e:FormEvent<HTMLFormElement>){
  e.preventDefault();setSaving(true);setNotice("");
  try{
   const db=getSupabase();
   const {data:{user},error:authError}=await db.auth.getUser();
   if(authError||!user){setNotice("Duhet të hysh në llogari për të regjistruar kompaninë.");return;}
   const {error}=await db.from("em_company_registration_requests").insert({
    requester_id:user.id,company_name:name.trim(),registration_number:nipt.trim().toUpperCase(),
    city:city.trim(),contact_email:email.trim(),representative_name:representative.trim(),phone:phone.trim(),address:address.trim(),industry:industry.trim(),website:website.trim(),description:description.trim(),status:"pending"
   });
   if(error){setNotice(error.code==="23505"?"Ke dërguar më parë kërkesë për këtë NIPT.":"Kërkesa nuk u ruajt: "+error.message);return;}
   setNotice("Kërkesa u regjistrua. Kompania nuk është aktivizuar ende; kërkon miratim.");
   setName("");setNipt("");setCity("");setEmail("");setRepresentative("");setPhone("");setAddress("");setIndustry("");setWebsite("");setDescription("");try{sessionStorage.removeItem("em_company_registration_draft");}catch{}
   await refresh();
  }catch{setNotice("Dërgimi dështoi. Kontrollo lidhjen.");}
  finally{setSaving(false);}
 }
 return <main className="section form-page">
  <span className="eyebrow">Bizneset në Shqipëri</span>
  <h1>Regjistro kompaninë</h1>
  <p>Dërgo kërkesën për verifikimin e kompanisë. Pas miratimit mund të krijohet anëtarësimi si pronar dhe të hapet paneli i punësimit.</p>
  <form className="listing-form" onSubmit={submit}>
   <label>Emri ligjor i kompanisë<input required minLength={2} maxLength={160} value={name} onChange={e=>setName(e.target.value)}/></label>
   <label>NIPT / NUIS<input required minLength={4} maxLength={40} value={nipt} onChange={e=>setNipt(e.target.value)}/></label>
   <label>Qyteti<input required minLength={2} maxLength={80} value={city} onChange={e=>setCity(e.target.value)}/></label>
   <label>Email kontakti<input required type="email" maxLength={254} value={email} onChange={e=>setEmail(e.target.value)}/></label>
   <label>Emri i përfaqësuesit<input required value={representative} onChange={e=>setRepresentative(e.target.value)}/></label>
   <label>Telefon kontakti<input required type="tel" value={phone} onChange={e=>setPhone(e.target.value)}/></label>
   <label>Adresa e biznesit<input required value={address} onChange={e=>setAddress(e.target.value)}/></label>
   <label>Fusha e aktivitetit<input required value={industry} onChange={e=>setIndustry(e.target.value)}/></label>
   <label>Website (opsionale)<input type="url" value={website} onChange={e=>setWebsite(e.target.value)}/></label>
   <label>Përshkrim i kompanisë<textarea value={description} onChange={e=>setDescription(e.target.value)}/></label>
   <button className="button primary" disabled={saving} type="submit">{saving?"Po dërgohet...":"Dërgo kërkesën"}</button>
   <p role="status" aria-live="polite">{notice}</p>
  </form>
  <section className="section"><h2>Kërkesat e mia</h2>
   {requests.length===0?<p>Nuk ka kërkesa të regjistruara.</p>:<div className="grid">{requests.map(r=><article className="tile" key={r.id}><h3>{r.company_name}</h3><p>{r.registration_number} · {r.city}</p><p>Statusi: {r.status}</p></article>)}</div>}
  </section>
  <Link href="/paneli-kompanise">Shko te paneli i kompanisë</Link>
 </main>;
}
