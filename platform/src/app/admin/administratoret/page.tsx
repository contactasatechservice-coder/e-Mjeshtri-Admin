"use client";
import {useEffect,useState} from "react";
import {getSupabase} from "@/lib/supabase";
export default function Administrators(){
const [list,setList]=useState<{id:string;email:string}[]>([]),[error,setError]=useState(""),[loading,setLoading]=useState(true);
useEffect(()=>{void(async()=>{try{const {data:{session}}=await getSupabase().auth.getSession();if(!session)throw Error("Kërkohet hyrja.");const r=await fetch("/api/admin/administrators",{headers:{Authorization:"Bearer "+session.access_token}});const data=await r.json();if(!r.ok)throw Error(data.error);setList(data.administrators)}catch(e){setError(String(e))}finally{setLoading(false)}})()},[]);
return <main className="admin-jobs"><h1>Administratorët</h1><p>Lista lexohet nga serveri pas verifikimit të autorizimit. Privilegjet nuk ndryshohen nga shfletuesi.</p>{loading?<p>Po ngarkohen...</p>:error?<p role="alert">{error}</p>:<div className="admin-jobs-list">{list.map(a=><article key={a.id}><h2>{a.email}</h2><small>{a.id}</small></article>)}</div>}<p>Kërkohet SUPABASE_SERVICE_ROLE_KEY në serverin Vercel.</p></main>
}