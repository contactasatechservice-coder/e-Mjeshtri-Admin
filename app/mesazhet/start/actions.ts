'use server';
import {redirect} from 'next/navigation';
import {requireRole} from '@/lib/server/require-role';
export async function startWorkerConversation(formData:FormData){
 const {client}=await requireRole(['citizen']);
 const workerId=formData.get('worker_id');
 if(typeof workerId!=='string'||!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(workerId))throw new Error('Mjeshtër i pavlefshëm');
 const {data,error}=await client.rpc('start_worker_conversation',{p_worker_id:workerId});
 if(error||typeof data!=='string')throw new Error('Nuk u krijua biseda');
 redirect('/mesazhet/'+data);
}
