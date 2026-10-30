"use client";
import {useEffect,useState} from "react";
import Link from "next/link";
import ListingForm from "@/components/listing-form";
import {getSupabase} from "@/lib/supabase";
export default function Page(){
 const [allowed,setAllowed]=useState(false);
 const [loading,setLoading]=useState(true);
 useEffect(()=>{let active=true;async function check(){try{const {data:{user}}=await getSupabase().auth.getUser();if(active)setAllowed(Boolean(user));}catch{if(active)setAllowed(false);}finally{if(active)setLoading(false);}}void check();return()=>{active=false;};},[]);
 return <main className="section form-page">
  <span className="eyebrow">Kërkesë për shërbim</span>
  <h1>Publiko një kërkesë për profesionist</h1>
  <p>Ke nevojë për hidraulik, elektricist apo një profesionist tjetër? Përshkruaj punën dhe buxhetin e përafërt.</p>
  <p><strong>Je kompani dhe kërkon punonjës?</strong> <Link href="/publiko-vend-pune">Publiko një vend pune</Link> nga llogaria e kompanisë së miratuar.</p>
  {loading?<p role="status">Po kontrollohet hyrja...</p>:allowed?<><p>Ky formular është ende demonstrues: të dhënat nuk publikohen dhe nuk ruhen.</p><ListingForm kind="job"/></>:<section className="tile"><h2>Hyr për të publikuar një punë</h2><p>Butoni i publikimit është i dukshëm për të gjithë, por kërkohet hyrja në llogari për të përdorur formularin.</p><Link className="button primary" href="/hyrje?redirect=%2Fpubliko-pune">Hyr në llogari</Link><p><Link href="/regjistrohu">Nuk ke llogari? Regjistrohu falas</Link></p></section>}
 </main>;
}
