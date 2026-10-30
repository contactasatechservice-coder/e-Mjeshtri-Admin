"use client";
import {useEffect,useState} from "react";
import {getSupabase} from "@/lib/supabase";
type Plan={id:string;name:string;price_all:number;period_days:number};
export default function Subscriptions(){const [plans,setPlans]=useState<Plan[]>([]);const [notice,setNotice]=useState("");useEffect(()=>{let active=true;async function load(){try{const {data,error}=await getSupabase().from("em_subscription_plans").select("id,name,price_all,period_days").eq("active",true);if(error)throw error;if(active)setPlans(data??[]);}catch{if(active)setNotice("Nuk u ngarkuan planet.");}}void load();return()=>{active=false};},[]);
return <main className="section"><h1>Abonimet</h1><p>Planet do të aktivizohen vetëm pas lidhjes me një procesor pagesash dhe verifikimit të pagesave në server. Nuk mblidhen të dhëna kartash këtu.</p><p role="status">{notice}</p>{plans.length===0&&<p>Nuk ka plane aktive aktualisht.</p>}<div className="grid">{plans.map(p=><article className="tile" key={p.id}><h2>{p.name}</h2><p>{p.price_all} Lekë / {p.period_days} ditë</p><p>Aktivizimi online nuk është ende i disponueshëm.</p></article>)}</div></main>;
}