"use client";
import {useMemo,useState} from "react";import Link from "next/link";
type Item={id:string;title:string;category:string;city:string;description:string;budget?:string;price?:string};
export default function MarketplaceList({items,kind}:{items:Item[];kind:"jobs"|"services"}){
 const [query,setQuery]=useState("");const [category,setCategory]=useState("Të gjitha");
 const categories=useMemo(()=>["Të gjitha",...new Set(items.map(x=>x.category))],[items]);
 const filtered=useMemo(()=>items.filter(x=>(category==="Të gjitha"||x.category===category)&&[x.title,x.city,x.description].join(" ").toLocaleLowerCase("sq").includes(query.trim().toLocaleLowerCase("sq"))),[items,category,query]);
 return <><div className="filters"><label>Kërko<input value={query} onChange={e=>setQuery(e.target.value)} placeholder="Shërbim, qytet ose fjalë kyçe"/></label><label>Kategoria<select value={category} onChange={e=>setCategory(e.target.value)}>{categories.map(c=><option key={c}>{c}</option>)}</select></label></div><p role="status">{filtered.length} rezultate demonstrimi</p><div className="grid">{filtered.map(x=><article className="tile" key={x.id}><span className="eyebrow">{x.category} · {x.city}</span><h3>{x.title}</h3><p>{x.description}</p><strong>{kind==="jobs"?x.budget:x.price}</strong>{kind==="jobs" ? <p><Link href={"/oferto/"+x.id}>Përgatit ofertë demo</Link></p> : null}</article>)}</div>{filtered.length===0&&<p>Nuk u gjet asnjë rezultat. Provo një kërkim tjetër.</p>}</>
}
