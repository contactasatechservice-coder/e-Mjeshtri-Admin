"use client";
import {useEffect,useState,type FormEvent} from "react";
import Link from "next/link";
import {useRouter} from "next/navigation";
import {getSupabase} from "@/lib/supabase";
type Kind="individual"|"company";
const cities=["Tiranë","Durrës","Elbasan","Shkodër","Vlorë","Fier","Korçë","Berat","Lushnjë","Kavajë","Burrel","Lezhë","Kukës","Pogradec","Sarandë","Gjirokastër","Tjetër"];
const field={width:"100%",boxSizing:"border-box" as const,minHeight:48,border:"1px solid #d6dee8",borderRadius:11,padding:"11px 13px",fontSize:15,background:"#fff",color:"#17334f"};
const label={display:"grid",gap:7,fontSize:14,fontWeight:650 as const,color:"#173b61"};
export default function Register(){
 const router=useRouter();const [kind,setKind]=useState<Kind>("individual");const [name,setName]=useState("");const [surname,setSurname]=useState("");const [phone,setPhone]=useState("");const [city,setCity]=useState("");const [occupation,setOccupation]=useState("citizen");const [profession,setProfession]=useState("");const [companyName,setCompanyName]=useState("");const [nipt,setNipt]=useState("");const [address,setAddress]=useState("");const [industry,setIndustry]=useState("");const [website,setWebsite]=useState("");const [description,setDescription]=useState("");const [email,setEmail]=useState("");const [password,setPassword]=useState("");const [confirm,setConfirm]=useState("");const [showPassword,setShowPassword]=useState(false);const [agree,setAgree]=useState(false);const [notice,setNotice]=useState("");const [busy,setBusy]=useState(false);
 useEffect(()=>{const kind=new URLSearchParams(window.location.search).get("lloji");if(kind==="kompani")setKind("company");if(kind==="mjeshter"){setKind("individual");setOccupation("master");}if(kind==="qytetar"){setKind("individual");setOccupation("citizen");}},[]);
 async function submit(e:FormEvent<HTMLFormElement>){
 e.preventDefault();if(password!==confirm){setNotice("Fjalëkalimet nuk përputhen.");return;}if(!agree){setNotice("Duhet të pranosh kushtet e përdorimit.");return;}setBusy(true);setNotice("");
 try{const db=getSupabase();const {data,error}=await db.auth.signUp({email:email.trim(),password,options:{data:{full_name:(name+" "+surname).trim(),phone:phone.trim(),city,account_type:kind==="company"?"company_applicant":occupation,profession:occupation==="master"?profession.trim():""}}});
 if(error){setNotice(error.message);return;}
 if(kind==="company"){
  const draft={company_name:companyName.trim(),registration_number:nipt.trim().toUpperCase(),city,contact_email:email.trim(),representative_name:(name+" "+surname).trim(),phone:phone.trim(),address:address.trim(),industry:industry.trim(),website:website.trim(),description:description.trim()};
  if(data.session&&data.user){const {error:requestError}=await db.from("em_company_registration_requests").insert({...draft,requester_id:data.user.id,status:"pending"});if(requestError){setNotice("Llogaria u krijua, por kërkesa e kompanisë nuk u dërgua: "+requestError.message+". Hyr dhe plotëso kërkesën.");return;}router.replace("/regjistro-kompani");return;}
  try{sessionStorage.setItem("em_company_registration_draft",JSON.stringify(draft));}catch{}
  setNotice("Llogaria u krijua. Konfirmo emailin nëse kërkohet, pastaj hyr dhe dërgo kërkesën e kompanisë për miratim.");
 }else if(data.session&&data.user){router.replace(occupation==="master"?"/paneli-mjeshtrit":"/paneli-qytetarit");return;}else{setNotice("Llogaria u krijua. Konfirmo emailin nëse kërkohet dhe hyr në platformë. Nuk nevojitet miratim nga Super Admin.");}
 }catch{setNotice("Regjistrimi nuk u përfundua. Provo përsëri.");}finally{setBusy(false);}
 }
 return <main style={{maxWidth:620,margin:"0 auto",padding:"24px 16px 64px"}}>
 <div style={{textAlign:"center",marginBottom:22}}><h1 style={{fontSize:29,color:"#0c4d91",marginBottom:7}}>Krijo llogarinë tënde</h1><p style={{fontSize:14,color:"#64748b"}}>Plotëso të dhënat për t'u bërë pjesë e e-Mjeshtri.</p></div>
 <div role="tablist" aria-label="Lloji i regjistrimit" style={{display:"grid",gridTemplateColumns:"1.5fr 1fr",gap:4,padding:5,background:"#edf0f5",borderRadius:14,marginBottom:20}}>
 {([{id:"individual",label:"Qytetar / Mjeshtër"},{id:"company",label:"Kompani"}] as const).map(t=><button key={t.id} type="button" role="tab" aria-selected={kind===t.id} onClick={()=>{setKind(t.id);setNotice("");}} style={{padding:"13px 6px",border:0,borderRadius:10,background:kind===t.id?"#fff":"transparent",boxShadow:kind===t.id?"0 2px 7px #1e293b15":"none",color:kind===t.id?"#0c4d91":"#526176",fontWeight:700,cursor:"pointer"}}>{t.label}</button>)}</div>
 <form onSubmit={submit} style={{display:"grid",gap:20}}>
 <section style={{background:"#fff",padding:18,border:"1px solid #e2e8f0",borderRadius:16}}>
 <h2 style={{fontSize:18,color:"#0c4d91",margin:"0 0 16px"}}>01 · Të dhënat personale</h2>
 <div style={{display:"grid",gridTemplateColumns:"repeat(2,minmax(0,1fr))",gap:12}}>
 <label style={label}>Emri *<input style={field} required minLength={2} maxLength={80} autoComplete="given-name" value={name} onChange={e=>setName(e.target.value)}/></label>
 <label style={label}>Mbiemri *<input style={field} required minLength={2} maxLength={80} autoComplete="family-name" value={surname} onChange={e=>setSurname(e.target.value)}/></label>
 </div>
 <div style={{display:"grid",gap:12,marginTop:12}}>
 <label style={label}>Numri i telefonit *<input style={field} required type="tel" minLength={7} maxLength={22} autoComplete="tel" placeholder="+355 6X XXX XXXX" value={phone} onChange={e=>setPhone(e.target.value)}/></label>
 <label style={label}>Qyteti *<select required style={field} value={city} onChange={e=>setCity(e.target.value)}><option value="">Zgjidh qytetin</option>{cities.map(c=><option key={c} value={c}>{c}</option>)}</select></label>
 </div></section>
 {kind==="individual"?<section style={{background:"#fff",padding:18,border:"1px solid #e2e8f0",borderRadius:16}}>
 <h2 style={{fontSize:18,color:"#0c4d91",margin:"0 0 15px"}}>02 · Profili yt</h2>
 <div style={{display:"grid",gap:10}}>
 <label style={{...label,display:"flex",alignItems:"center",gap:9}}><input type="radio" name="occupation" checked={occupation==="citizen"} onChange={()=>setOccupation("citizen")}/> Qytetar — kërkoj shërbime</label>
 <label style={{...label,display:"flex",alignItems:"center",gap:9}}><input type="radio" name="occupation" checked={occupation==="master"} onChange={()=>setOccupation("master")}/> Mjeshtër — ofroj shërbime</label>
 {occupation==="master"&&<label style={label}>Profesioni / specialiteti *<input style={field} required maxLength={100} placeholder="P.sh. Elektricist, hidraulik, marangoz" value={profession} onChange={e=>setProfession(e.target.value)}/></label>}
 </div></section>:<section style={{background:"#fff",padding:18,border:"1px solid #e2e8f0",borderRadius:16}}>
 <h2 style={{fontSize:18,color:"#0c4d91",margin:"0 0 15px"}}>02 · Të dhënat e kompanisë</h2>
 <div style={{display:"grid",gap:12}}>
 <label style={label}>Emri ligjor i kompanisë *<input style={field} required minLength={2} maxLength={160} value={companyName} onChange={e=>setCompanyName(e.target.value)}/></label>
 <label style={label}>NIPT / NUIS *<input style={field} required minLength={4} maxLength={40} value={nipt} onChange={e=>setNipt(e.target.value)}/></label>
 <label style={label}>Adresa e biznesit *<input style={field} required maxLength={250} value={address} onChange={e=>setAddress(e.target.value)}/></label>
 <label style={label}>Fusha e aktivitetit *<input style={field} required maxLength={120} placeholder="P.sh. Ndërtim, IT, tregti" value={industry} onChange={e=>setIndustry(e.target.value)}/></label>
 <label style={label}>Faqja e internetit (opsionale)<input style={field} type="url" placeholder="https://..." value={website} onChange={e=>setWebsite(e.target.value)}/></label>
 <label style={label}>Përshkrimi i kompanisë<textarea style={{...field,minHeight:88,resize:"vertical"}} maxLength={1000} value={description} onChange={e=>setDescription(e.target.value)}/></label>
 </div><p style={{fontSize:13,color:"#92400e",marginTop:14}}>Kompania qëndron në pritje derisa Super Admin të verifikojë dhe miratojë kërkesën.</p></section>}
 <section style={{background:"#fff",padding:18,border:"1px solid #e2e8f0",borderRadius:16}}>
 <h2 style={{fontSize:18,color:"#0c4d91",margin:"0 0 15px"}}>03 · Siguria e llogarisë</h2>
 <div style={{display:"grid",gap:12}}>
 <label style={label}>Adresa e emailit *<input style={field} required type="email" autoComplete="email" value={email} onChange={e=>setEmail(e.target.value)}/></label>
 <label style={label}>Fjalëkalimi *<div style={{position:"relative"}}><input style={{...field,paddingRight:70}} required minLength={8} type={showPassword?"text":"password"} autoComplete="new-password" value={password} onChange={e=>setPassword(e.target.value)}/><button type="button" onClick={()=>setShowPassword(v=>!v)} style={{position:"absolute",right:9,top:10,border:0,background:"transparent",color:"#0c4d91",fontWeight:700}}>{showPassword?"Fshih":"Shfaq"}</button></div></label>
 <label style={label}>Konfirmo fjalëkalimin *<input style={field} required minLength={8} type={showPassword?"text":"password"} autoComplete="new-password" value={confirm} onChange={e=>setConfirm(e.target.value)}/></label>
 </div></section>
 <label style={{display:"flex",gap:10,alignItems:"flex-start",fontSize:13,color:"#465a70"}}><input required type="checkbox" checked={agree} onChange={e=>setAgree(e.target.checked)} style={{marginTop:3}}/> Konfirmoj që të dhënat janë të sakta dhe pranoj kushtet e përdorimit dhe përpunimin e të dhënave për regjistrimin e llogarisë.</label>
 <button disabled={busy} className="button primary" type="submit" style={{width:"100%",minHeight:54,borderRadius:12,fontWeight:750,fontSize:16}}>{busy?"Duke u regjistruar...":kind==="company"?"Regjistrohu dhe dërgo kërkesën":"Krijo llogari falas"}</button>
 </form><p role="status" aria-live="polite" style={{marginTop:15,color:"#174d78"}}>{notice}</p>
 {kind==="company"&&<p style={{fontSize:14}}><Link href="/regjistro-kompani">Ke llogari? Dërgo kërkesën e kompanisë</Link></p>}
 <p style={{textAlign:"center",marginTop:24}}>Ke llogari? <Link href="/hyrje">Hyr në platformë</Link></p>
 </main>;
}
