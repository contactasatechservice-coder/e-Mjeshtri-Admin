import Link from 'next/link';
import {requireRole} from '@/lib/server/require-role';
import {startWorkerConversation} from './actions';
export default async function StartConversationPage(){
 const {client}=await requireRole(['citizen']);
 const {data:workers,error}=await client.from('worker_profiles').select('user_id,bio,available').eq('available',true).limit(50);
 const ids=(workers??[]).map(w=>w.user_id);
 const {data:profiles}=ids.length?await client.from('profiles').select('id,full_name,city').in('id',ids):{data:[]};
 const byId=new Map((profiles??[]).map(p=>[p.id,p]));
 return <main className="shell"><header className="top"><Link href="/mesazhet" className="logo">← Mesazhet</Link></header><section className="auth" style={{maxWidth:800}}><h1>Kontakto një mjeshtër</h1><p>Zgjidh një mjeshtër të disponueshëm për të nisur bisedën.</p>{error?<p role="alert">Mjeshtrat nuk u ngarkuan.</p>:!workers?.length?<p>Nuk ka mjeshtër të disponueshëm për momentin.</p>:<ul className="company-applications">{workers.map(worker=><li key={worker.user_id}><strong>{byId.get(worker.user_id)?.full_name??'Mjeshtër'}</strong><p>{byId.get(worker.user_id)?.city??''}</p><p>{worker.bio}</p><form action={startWorkerConversation}><input type="hidden" name="worker_id" value={worker.user_id}/><button type="submit">Nis bisedën</button></form></li>)}</ul>}</section></main>;
}
