'use server';
import {revalidatePath} from 'next/cache';
import {redirect} from 'next/navigation';
import {requireRole} from '@/lib/server/require-role';
export async function applyForJob(formData:FormData){
 const {user,client}=await requireRole(['citizen','worker']);
 const jobId=formData.get('job_id'), letter=formData.get('cover_letter');
 if(typeof jobId!=='string'||!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(jobId))throw new Error('Oferta nuk është e vlefshme');
 if(typeof letter!=='string'||letter.length>2000)throw new Error('Mesazhi është shumë i gjatë');
 const {data:job,error:jobError}=await client.from('job_posts').select('id').eq('id',jobId).eq('status','published').maybeSingle();
 if(jobError||!job)throw new Error('Kjo ofertë nuk është më e disponueshme');
 const {error}=await client.from('job_applications').insert({job_id:jobId,applicant_id:user.id,cover_letter:letter.trim()||null});
 if(error){if(error.code==='23505')throw new Error('Ke aplikuar më parë për këtë ofertë');throw new Error('Aplikimi nuk u ruajt');}
 revalidatePath('/panel/qytetar');
 redirect('/panel');
}
