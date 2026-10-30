"use client";
import { useState, type FormEvent } from "react";
import Link from "next/link";

const types = ["Kohë e plotë", "Kohë e pjesshme", "Me turne", "Praktikë", "Kontratë projekti"];
export default function PublishJob() {
  const [title,setTitle]=useState("");
  const [company,setCompany]=useState("");
  const [city,setCity]=useState("");
  const [type,setType]=useState(types[0]);
  const [description,setDescription]=useState("");
  const [requirements,setRequirements]=useState("");
  const [salaryMin,setSalaryMin]=useState("");
  const [salaryMax,setSalaryMax]=useState("");
  const [notice,setNotice]=useState("");
  function submit(e:FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (title.trim().length<5 || company.trim().length<2 || city.trim().length<2 || description.trim().length<30) {
      setNotice("Plotëso titullin, kompaninë, qytetin dhe përshkrimin me të paktën 30 karaktere.");
      return;
    }
    const min=salaryMin===""?null:Number(salaryMin);
    const max=salaryMax===""?null:Number(salaryMax);
    if ((min!==null && (!Number.isFinite(min)||min<0)) || (max!==null && (!Number.isFinite(max)||max<0)) || (min!==null && max!==null && min>max)) {
      setNotice("Kontrollo intervalin e pagës: minimumi nuk mund të jetë më i madh se maksimumi.");
      return;
    }
    setNotice("Formulari është i plotësuar, por shpallja NUK u publikua dhe NUK u ruajt. Aktivizimi kërkon migrimet e testuara, hyrjen dhe verifikimin e kompanisë.");
  }
  return <main className="section form-page">
    <span className="eyebrow">Punësim në Shqipëri</span>
    <h1>Publiko një vend pune</h1>
    <p>Kjo faqe është për kompanitë që kërkojnë punonjës. Për një shërbim të përkohshëm, përdor <Link href="/publiko-pune" style={{textDecoration:"underline"}}>kërkesën për profesionist</Link>.</p>
    <p role="status" className="form-note">Version paraprak: formulari kryen vetëm kontrollin e fushave. Asnjë e dhënë nuk ruhet ose publikohet.</p>
    <form className="listing-form" onSubmit={submit}>
      <label>Emri i kompanisë<input required minLength={2} maxLength={120} value={company} onChange={e=>setCompany(e.target.value)} placeholder="Emri i biznesit"/></label>
      <label>Pozicioni i punës<input required minLength={5} maxLength={160} value={title} onChange={e=>setTitle(e.target.value)} placeholder="P.sh. Teknik IT"/></label>
      <label>Qyteti<input required minLength={2} maxLength={80} value={city} onChange={e=>setCity(e.target.value)} placeholder="P.sh. Tiranë"/></label>
      <label>Lloji i punës<select value={type} onChange={e=>setType(e.target.value)}>{types.map(t=><option key={t}>{t}</option>)}</select></label>
      <label>Paga minimale (Lekë, opsionale)<input type="number" min="0" step="1" value={salaryMin} onChange={e=>setSalaryMin(e.target.value)}/></label>
      <label>Paga maksimale (Lekë, opsionale)<input type="number" min="0" step="1" value={salaryMax} onChange={e=>setSalaryMax(e.target.value)}/></label>
      <label>Përshkrimi i pozicionit<textarea required minLength={30} maxLength={5000} rows={6} value={description} onChange={e=>setDescription(e.target.value)} placeholder="Detyrat, orari, vendndodhja dhe përfitimet..."/></label>
      <label>Kriteret për kandidatët<textarea maxLength={3000} rows={4} value={requirements} onChange={e=>setRequirements(e.target.value)} placeholder="Eksperienca, aftësitë dhe kualifikimet..."/></label>
      <button className="button primary" type="submit">Kontrollo shpalljen</button>
      <p role="status" aria-live="polite">{notice}</p>
    </form>
  </main>;
}
