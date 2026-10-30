import Link from 'next/link';
import {requireRole} from '@/lib/server/require-role';
export default async function MessagesPage(){
 const {user,client}=await requireRole(['citizen','worker','company']);
 const {data:memberships,error}=await client.from('conversation_members').select('conversation_id').eq('user_id',user.id).limit(100);
 const ids=(memberships??[]).map(m=>m.conversation_id);
 const {data:messages}=ids.length?await client.from('messages').select('conversation_id,body,created_at').in('conversation_id',ids).order('created_at',{ascending:false}).limit(100):{data:[]};
 const latest=new Map<string,{body:string,created_at:string}>();
 for(const message of messages??[])if(!latest.has(message.conversation_id))latest.set(message.conversation_id,message);
 return <main className="shell"><header className="top"><Link className="logo" href="/panel">e-Mjeshtri</Link></header><section className="auth" style={{maxWidth:760}}><h1>Mesazhet e mia</h1><p><Link href="/mesazhet/start">+ Nis bisedë me mjeshtër</Link></p>{error?<p role="alert">Bisedat nuk u ngarkuan.</p>:ids.length===0?<p>Nuk ke ende biseda.</p>:<ul className="citizen-activity-list">{ids.map(id=><li key={id}><Link href={`/mesazhet/${id}`}>Hap bisedën</Link><span>{latest.get(id)?.body.slice(0,80)??'Bisedë e re'}</span></li>)}</ul>}<Link href="/panel">Kthehu te paneli</Link></section></main>;
}
