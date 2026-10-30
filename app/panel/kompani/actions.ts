'use server';
import {revalidatePath} from 'next/cache';
import {requireRole} from '@/lib/server/require-role';

export async function changeApplicationStatus(formData:FormData){
 const {user,client}=await requireRole(['company']);
 const id=formData.get('application_id'),status=formData.get('status');
 if(typeof id!=='string'||!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(id))throw new Error('Aplikimi nuk është i vlefshëm');
 if(status!=='reviewing'&&status!=='interview'&&status!=='accepted'&&status!=='rejected')throw new Error('Statusi nuk është i vlefshëm');
 const {data:application,error:readError}=await client.from('job_applications').select('id,job_id,status').eq('id',id).maybeSingle();
 if(readError||!application)throw new Error('Aplikimi nuk u gjet');
 const {data:job,error:jobError}=await client.from('job_posts').select('id').eq('id',application.job_id).eq('company_id',user.id).maybeSingle();
 if(jobError||!job)throw new Error('Nuk ke leje për këtë aplikim');
 if(!['applied','reviewing','interview'].includes(application.status))throw new Error('Aplikimi është mbyllur');
 const {data:updated,error}=await client.from('job_applications').update({status}).eq('id',id).eq('status',application.status).select('id').maybeSingle();
 if(error||!updated)throw new Error('Statusi nuk u ndryshua. Rifresko faqen dhe provo sërish.');
 revalidatePath('/panel/kompani');
}
