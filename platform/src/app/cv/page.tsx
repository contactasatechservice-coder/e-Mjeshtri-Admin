"use client";
import {useEffect,useState,type ChangeEvent} from "react";
import Link from "next/link";
import {getSupabase} from "@/lib/supabase";
type Document={id:string;file_name:string;storage_path:string;created_at:string};
export default function CandidateCV(){
 const [file,setFile]=useState<File|null>(null);const [docs,setDocs]=useState<Document[]>([]);const [notice,setNotice]=useState("");const [busy,setBusy]=useState(false);
 async function load(){try{const db=getSupabase();const {data:{user}}=await db.auth.getUser();if(!user){setNotice("Hyr në llogari për të menaxhuar CV-në.");return;}const {data,error}=await db.from("em_candidate_documents").select("id,file_name,storage_path,created_at").eq("user_id",user.id).order("created_at",{ascending:false});if(error)throw error;setDocs(data??[]);}catch{setNotice("Dokumentet nuk u ngarkuan.");}}
 useEffect(()=>{void load();},[]);
 function choose(e:ChangeEvent<HTMLInputElement>){setFile(e.target.files?.[0]??null);}
 async function upload(){if(!file)return;if(file.type!=="application/pdf"||file.size>5*1024*1024||file.size===0){setNotice("Pranohet vetëm PDF deri në 5 MB.");return;}setBusy(true);setNotice("");try{
  const db=getSupabase();const {data:{user}}=await db.auth.getUser();if(!user){setNotice("Hyr në llogari.");return;}
  const path=user.id+"/"+crypto.randomUUID()+".pdf";
  const {error:uploadError}=await db.storage.from("em-candidate-cv").upload(path,file,{contentType:"application/pdf",upsert:false});
  if(uploadError){setNotice("CV nuk u ngarkua: "+uploadError.message);return;}
  const {error:metadataError}=await db.from("em_candidate_documents").insert({user_id:user.id,storage_path:path,file_name:file.name.slice(0,200)});
  if(metadataError){await db.storage.from("em-candidate-cv").remove([path]);setNotice("CV u ngarkua, por regjistrimi dështoi: "+metadataError.message);return;}
  setFile(null);setNotice("CV u ruajt privatisht.");await load();
 }catch{setNotice("Gabim gjatë ngarkimit.");}finally{setBusy(false);}}
 async function view(path:string){const {data,error}=await getSupabase().storage.from("em-candidate-cv").createSignedUrl(path,60);if(error||!data?.signedUrl){setNotice("Nuk u hap CV-ja.");return;}window.open(data.signedUrl,"_blank","noopener,noreferrer");}
 return <main className="section form-page"><span className="eyebrow">Dokumentet e kandidatit</span><h1>CV private</h1><p>Ngarko CV në PDF deri në 5 MB. Dokumentet ruhen në hapësirë private dhe nuk publikohen në profilin tënd.</p><div className="listing-form"><label>Zgjidh CV<input type="file" accept="application/pdf,.pdf" onChange={choose}/></label><button type="button" className="button primary" disabled={busy||!file} onClick={()=>void upload()}>{busy?"Po ngarkohet...":"Ngarko CV"}</button><p role="status">{notice}</p></div><h2>Dokumentet e mia</h2>{docs.length===0&&<p>Nuk ke CV të ruajtur.</p>}<div className="grid">{docs.map(d=><article className="tile" key={d.id}><h3>{d.file_name}</h3><p>{new Date(d.created_at).toLocaleDateString("sq-AL")}</p><button className="button secondary" type="button" onClick={()=>void view(d.storage_path)}>Hap për 60 sekonda</button></article>)}</div><Link href="/kerkoj-pune">Profili Kërkoj punë</Link></main>;
}
