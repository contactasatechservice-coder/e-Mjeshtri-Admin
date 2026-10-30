import Link from 'next/link';
import {requireRole} from '@/lib/server/require-role';
import {applyForJob} from '../actions';
export default async function ApplyPage({params}:{params:Promise<{id:string}>}){
 const {id}=await params;
 const {client}=await requireRole(['citizen','worker']);
 if(!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(id))return <main className="shell"><p>Oferta nuk është e vlefshme.</p></main>;
 const {data:job}=await client.from('job_posts').select('id,title,description,city').eq('id',id).eq('status','published').maybeSingle();
 return <main className="shell"><header className="top"><Link href="/oferta-pune" className="logo">← Oferta pune</Link></header><section className="auth" style={{maxWidth:720}}>{!job?<h1>Oferta nuk është më e disponueshme.</h1>:<><h1>{job.title}</h1>{job.city&&<p>{job.city}</p>}<p>{job.description}</p><form action={applyForJob} className="citizen-form"><input type="hidden" name="job_id" value={job.id}/><label htmlFor="cover_letter">Mesazh për kompaninë (opsional)</label><textarea id="cover_letter" name="cover_letter" rows={5} maxLength={2000} placeholder="Përshkruaj përvojën dhe interesin tënd"/><button type="submit">Dërgo aplikimin</button></form></>}</section></main>;
}
