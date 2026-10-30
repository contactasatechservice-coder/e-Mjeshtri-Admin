"use client";
import { useEffect, useState, type FormEvent } from "react";
import Link from "next/link";
import {getSupabase} from "@/lib/supabase";

const types = ["Kohë e plotë", "Kohë e pjesshme", "Me turne", "Praktikë", "Kontratë projekti"];
export default function PublishJob() {
  const [title,setTitle]=useState("");
  const [businessId,setBusinessId]=useState("");
  const [companies,setCompanies]=useState<{id:string;name:string}[]>([]);
  const [companyNotice,setCompanyNotice]=useState("Po kontrollohen kompanitë...");
  useEffect(()=>{let active=true;async function load(){try{const db=getSupabase();const {data:{user}}=await db.auth.getUser();if(!user){if(active)setCompanyNotice("Identifikohu për të zgjedhur kompaninë.");return;}const {data:members,error}=await db.from("em_company_memberships").select("business_id").eq("user_id",user.id).eq("status","active").in("role",["owner","manager","recruiter"]);if(error)throw error;const ids=(members??[]).map(m=>m.business_id);if(!ids.length){if(active)setCompanyNotice("Nuk ke ende kompani të autorizuar.");return;}const {data,error:companiesError}=await db.from("em_companies").select("id,name").in("id",ids);if(companiesError)throw companiesError;if(active){setCompanies(data??[]);setBusinessId(data?.[0]?.id??"");setCompanyNotice("");}}catch{if(active)setCompanyNotice("Nuk u ngarkuan kompanitë.");}}void load();return()=>{active=false};},[]);
  const [saving,setSaving]=useState(false);
  const [city,setCity]=useState("");
  const [type,setType]=useState(types[0]);
  const [description,setDescription]=useState("");
  const [requirements,setRequirements]=useState("");
  const [salaryMin,setSalaryMin]=useState("");
  const [salaryMax,setSalaryMax]=useState("");
  const [notice,setNotice]=useState("");
  async function submit(e:FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (title.trim().length<5 || !businessId || city.trim().length<2 || description.trim().length<30) {
      setNotice("Plotëso titullin, kompaninë, qytetin dhe përshkrimin me të paktën 30 karaktere.");
      return;
    }
    const min=salaryMin===""?null:Number(salaryMin);
    const max=salaryMax===""?null:Number(salaryMax);
    if ((min!==null && (!Number.isFinite(min)||min<0)) || (max!==null && (!Number.isFinite(max)||max<0)) || (min!==null && max!==null && min>max)) {
      setNotice("Kontrollo intervalin e pagës: minimumi nuk mund të jetë më i madh se maksimumi.");
      return;
    }
    setSaving(true);
    try {
      const supabase=getSupabase();
      const {data:{user},error:authError}=await supabase.auth.getUser();
      if(authError||!user){setNotice("Identifikohu për të ruajtur shpalljen.");return;}
      const {data:member,error:membershipError}=await supabase.from("em_company_memberships")
        .select("business_id").eq("user_id",user.id).eq("business_id",businessId)
        .eq("status","active").in("role",["owner","manager","recruiter"]).maybeSingle();
      if(membershipError||!member){setNotice("Nuk ke autorizim aktiv për këtë kompani.");return;}
      const {error}=await supabase.from("em_job_postings").insert({
        business_id:businessId,title:title.trim(),city:city.trim(),
        description:description.trim()+(requirements.trim()?"\\n\\nKriteret:\\n"+requirements.trim():""),
        employment_type:type,salary_min:min,salary_max:max,currency:"ALL",status:"draft"
      });
      if(error){setNotice("Shpallja nuk u ruajt: "+error.message);return;}
      setNotice("Shpallja u ruajt si draft. Nuk është publikuar ende.");
    }catch{setNotice("Ruajtja dështoi. Kontrollo lidhjen ose konfigurimin.");}
    finally{setSaving(false);}
  }
  return <main className="section form-page">
    <span className="eyebrow">Punësim në Shqipëri</span>
    <h1>Publiko një vend pune</h1>
    <p>Kjo faqe është për kompanitë që kërkojnë punonjës. Për një shërbim të përkohshëm, përdor <Link href="/publiko-pune" style={{textDecoration:"underline"}}>kërkesën për profesionist</Link>.</p>
    <p role="status" className="form-note">Shpalljet ruhen si draft për anëtarët e autorizuar të kompanisë. Publikimi aktivizohet më vonë.</p>
    <form className="listing-form" onSubmit={submit}>
      <label>Kompania<select required value={businessId} onChange={e=>setBusinessId(e.target.value)}><option value="">Zgjidh kompaninë</option>{companies.map(c=><option key={c.id} value={c.id}>{c.name}</option>)}</select></label>{companyNotice&&<p role="status">{companyNotice}</p>}
      <label>Pozicioni i punës<input required minLength={5} maxLength={160} value={title} onChange={e=>setTitle(e.target.value)} placeholder="P.sh. Teknik IT"/></label>
      <label>Qyteti<input required minLength={2} maxLength={80} value={city} onChange={e=>setCity(e.target.value)} placeholder="P.sh. Tiranë"/></label>
      <label>Lloji i punës<select value={type} onChange={e=>setType(e.target.value)}>{types.map(t=><option key={t}>{t}</option>)}</select></label>
      <label>Paga minimale (Lekë, opsionale)<input type="number" min="0" step="1" value={salaryMin} onChange={e=>setSalaryMin(e.target.value)}/></label>
      <label>Paga maksimale (Lekë, opsionale)<input type="number" min="0" step="1" value={salaryMax} onChange={e=>setSalaryMax(e.target.value)}/></label>
      <label>Përshkrimi i pozicionit<textarea required minLength={30} maxLength={5000} rows={6} value={description} onChange={e=>setDescription(e.target.value)} placeholder="Detyrat, orari, vendndodhja dhe përfitimet..."/></label>
      <label>Kriteret për kandidatët<textarea maxLength={3000} rows={4} value={requirements} onChange={e=>setRequirements(e.target.value)} placeholder="Eksperienca, aftësitë dhe kualifikimet..."/></label>
      <button className="button primary" disabled={saving} type="submit">{saving?"Po ruhet...":"Ruaj si draft"}</button>
      <p role="status" aria-live="polite">{notice}</p>
    </form>
  </main>;
}
