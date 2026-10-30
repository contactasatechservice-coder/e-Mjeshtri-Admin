"use client";
import {useEffect,useState} from "react";
import Link from "next/link";
import {getSupabase} from "@/lib/supabase";
type Request={id:string;title:string;city:string;status:string;created_at:string};
type Interest={id:string;request_id:string;professional_id:string;message:string;status:string;created_at:string};
type Profile={user_id:string;display_name:string;profession:string;city:string};
type Review={request_id:string;professional_id:string;rating:number;comment:string};
export default function MyRequests(){
 const [userId,setUserId]=useState<string|null>(null);const [loading,setLoading]=useState(true);const [requests,setRequests]=useState<Request[]>([]);const [interests,setInterests]=useState<Interest[]>([]);const [profiles,setProfiles]=useState<Profile[]>([]);const [notice,setNotice]=useState("");const [working,setWorking]=useState<string|null>(null);const [reviews,setReviews]=useState<Review[]>([]);const [ratings,setRatings]=useState<Record<string,number>>({});const [comments,setComments]=useState<Record<string,string>>({});
 async function load(user:string){const db=getSupabase();const {data:jobs,error}=await db.from("em_service_requests").select("id,title,city,status,created_at").eq("customer_id",user).order("created_at",{ascending:false}).limit(100);if(error)throw error;const list=jobs??[];setRequests(list);const {data:existingReviews}=list.length?await db.from("em_professional_reviews").select("request_id,professional_id,rating,comment").in("request_id",list.map(x=>x.id)):{data:[]};setReviews(existingReviews??[]);if(!list.length){setInterests([]);setProfiles([]);return;}const {data:responses,error:responseError}=await db.from("em_service_interests").select("id,request_id,professional_id,message,status,created_at").in("request_id",list.map(x=>x.id)).order("created_at",{ascending:false});if(responseError)throw responseError;setInterests(responses??[]);const ids=[...new Set((responses??[]).map(x=>x.professional_id))];if(ids.length){const {data:people}=await db.from("em_professional_profiles").select("user_id,display_name,profession,city").in("user_id",ids).eq("is_public",true);setProfiles(people??[]);}else setProfiles([]);}
 useEffect(()=>{let active=true;(async()=>{try{const {data:{user}}=await getSupabase().auth.getUser();if(!active||!user)return;setUserId(user.id);await load(user.id);}catch(e){if(active)setNotice("Nuk u ngarkuan kërkesat: "+(e instanceof Error?e.message:"Gabim"));}finally{if(active)setLoading(false);}})();return()=>{active=false;};},[]);
 async function submitReview(requestId:string,professionalId:string){if(!userId)return;const rating=ratings[requestId]??0;if(rating<1||rating>5){setNotice("Zgjidh nga 1 deri në 5 yje.");return;}setWorking(requestId);setNotice("");try{const {error}=await getSupabase().from("em_professional_reviews").insert({request_id:requestId,professional_id:professionalId,reviewer_id:userId,rating,comment:(comments[requestId]??"").trim()});if(error)throw error;await load(userId);setNotice("Vlerësimi u publikua me sukses.");}catch(e){setNotice("Vlerësimi dështoi: "+(e instanceof Error?e.message:"Gabim"));}finally{setWorking(null);}}
 async function changeStatus(id:string,status:"completed"|"cancelled"){if(!userId)return;setWorking(id);setNotice("");try{const {data,error}=await getSupabase().from("em_service_requests").update({status}).eq("id",id).eq("customer_id",userId).eq("status","open").select("id").single();if(error||!data)throw error??new Error("Kërkesa nuk u përditësua.");await load(userId);setNotice(status==="completed"?"Puna u shënua si e përfunduar.":"Kërkesa u anulua.");}catch(e){setNotice("Veprimi dështoi: "+(e instanceof Error?e.message:"Gabim"));}finally{setWorking(null);}}
 async function choose(interest:Interest,status:"selected"|"declined"){if(!userId)return;setWorking(interest.id);setNotice("");try{const {error}=await getSupabase().from("em_service_interests").update({status}).eq("id",interest.id).select("id").single();if(error)throw error;await load(userId);setNotice(status==="selected"?"Mjeshtri u përzgjodh.":"Interesimi u refuzua.");}catch(e){setNotice("Veprimi dështoi: "+(e instanceof Error?e.message:"Gabim"));}finally{setWorking(null);}}
 return <main className="section" style={{maxWidth:900,margin:"0 auto"}}>
 <h1>Kërkesat e mia</h1><p>Menaxho kërkesat, përzgjedh mjeshtrin dhe vlerëso punën e përfunduar.</p>
 {loading?<p>Po ngarkohen...</p>:!userId?<p><Link href="/hyrje">Hyr në llogari</Link></p>:requests.length===0?<p>Nuk ke ende kërkesa. <Link href="/publiko-pune">Publiko një punë</Link></p>:<div style={{display:"grid",gap:16}}>{requests.map(job=>{
 const related=interests.filter(i=>i.request_id===job.id);
 const chosen=related.find(i=>i.status==="selected");
 const review=reviews.find(r=>r.request_id===job.id);
 return <section className="tile" key={job.id}>
 <h2>{job.title}</h2><p>{job.city} · {job.status}</p>
 {job.status==="open"&&<div style={{display:"flex",gap:8,flexWrap:"wrap"}}>
 {chosen&&<button className="button primary" type="button" disabled={working!==null} onClick={()=>void changeStatus(job.id,"completed")}>Përfundo punën</button>}
 <button type="button" disabled={working!==null} onClick={()=>void changeStatus(job.id,"cancelled")}>Anulo kërkesën</button></div>}
 {chosen&&<p><Link href="/mesazhet">Mesazhet me mjeshtrin</Link></p>}
 {job.status==="completed"&&chosen&&<div style={{padding:14,border:"1px solid #e2e8f0",borderRadius:12}}>
 <h3>Vlerëso mjeshtrin</h3>
 {review?<p>{"★".repeat(review.rating)}{"☆".repeat(5-review.rating)} · {review.comment||"Pa koment"}</p>:<div style={{display:"grid",gap:10}}>
 <label>Yjet <select value={ratings[job.id]??0} onChange={e=>setRatings(v=>({...v,[job.id]:Number(e.target.value)}))}><option value={0}>Zgjidh</option>{[1,2,3,4,5].map(n=><option key={n} value={n}>{n} ★</option>)}</select></label>
 <label>Komenti <textarea rows={3} maxLength={1000} value={comments[job.id]??""} onChange={e=>setComments(v=>({...v,[job.id]:e.target.value}))}/></label>
 <button className="button primary" type="button" disabled={working!==null} onClick={()=>void submitReview(job.id,chosen.professional_id)}>Publiko vlerësimin</button></div>}</div>}
 <h3>Interesimet ({related.length})</h3>
 {related.length===0?<p>Ende nuk ka interesime.</p>:related.map(i=>{
 const person=profiles.find(p=>p.user_id===i.professional_id);
 return <article key={i.id} style={{padding:"12px 0",borderTop:"1px solid #e2e8f0"}}>
 <strong>{person?.display_name??"Profesionist"}</strong><p>{person?.profession??"Mjeshtër"} · {person?.city??""}</p><p>{i.message}</p><p>{i.status==="selected"?"I përzgjedhur":i.status==="declined"?"I refuzuar":"Në pritje"}</p>
 {i.status==="interested"&&job.status==="open"&&<div style={{display:"flex",gap:8}}>
 {!chosen&&<button className="button primary" type="button" disabled={working!==null} onClick={()=>void choose(i,"selected")}>Zgjidh mjeshtrin</button>}
 <button type="button" disabled={working!==null} onClick={()=>void choose(i,"declined")}>Refuzo</button></div>}</article>;
 })}</section>;
 })}</div>}
 <p role="status">{notice}</p><p><Link href="/paneli-qytetarit">Kthehu te paneli</Link></p></main>;
}
