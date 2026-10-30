import Link from "next/link";
import {navigation} from "../navigation";
import AdminIcon from "../admin-icon";
export default async function AdminSection({params}:{params:Promise<{section:string}>}){
 const {section}=await params;
 const item=navigation.find(x=>x.href==="/admin/"+section);
 if(!item)return <main className="admin-placeholder"><h1>Faqja nuk u gjet</h1><Link href="/admin">Kthehu në Dashboard</Link></main>;
 return <main className="admin-placeholder"><div className="admin-placeholder-heading"><AdminIcon name={item.icon}/><div><span className="admin-eyebrow">SUPER ADMIN</span><h1>{item.title}</h1></div></div><div className="admin-placeholder-card"><h2>Moduli në përgatitje</h2><p>Kjo faqe është pjesë e panelit ekzistues e-Mjeshtri. Funksionet e administrimit do të aktivizohen pasi të lidhen dhe testohen me databazën. Deri atëherë nuk mund të bëhen ndryshime nga kjo faqe.</p><Link href="/admin">← Kthehu në Dashboard</Link></div></main>;
}
