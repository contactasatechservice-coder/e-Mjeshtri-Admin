"use client";
import {useEffect,useState} from "react";
import {getSupabase} from "@/lib/supabase";
type Ad={id:string;title:string;description:string;destination_url:string|null};
export default function PublicAdvertisements(){
const [ads,setAds]=useState<Ad[]>([]);
useEffect(()=>{let active=true;void(async()=>{try{const {data,error}=await getSupabase().from("em_advertisements").select("id,title,description,destination_url").eq("active",true).order("created_at",{ascending:false}).limit(3);if(!error&&active)setAds((data??[]) as Ad[])}catch{}})();return()=>{active=false}},[]);
if(!ads.length)return null;
return <section aria-label="Reklama" style={{marginTop:28}}><h2>Reklama</h2><div className="grid">{ads.map(ad=><article className="tile" key={ad.id}><small>Reklamë</small><h3>{ad.title}</h3><p>{ad.description}</p>{ad.destination_url&&<a href={ad.destination_url} rel="sponsored noopener noreferrer" target="_blank">Shiko ofertën</a>}</article>)}</div></section>;
}