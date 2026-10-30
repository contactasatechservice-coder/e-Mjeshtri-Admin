'use server';
import {revalidatePath} from 'next/cache';
import {requireRole} from '@/lib/server/require-role';
export async function sendMessage(formData:FormData){
 const {user,client}=await requireRole(['citizen','worker','company']);
 const conversationId=formData.get('conversation_id'),body=formData.get('body');
 if(typeof conversationId!=='string'||!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(conversationId))throw new Error('Bisedë e pavlefshme');
 if(typeof body!=='string'||!body.trim()||body.trim().length>3000)throw new Error('Mesazhi duhet të ketë 1 deri 3000 karaktere');
 const {data:membership,error:membershipError}=await client.from('conversation_members').select('conversation_id').eq('conversation_id',conversationId).eq('user_id',user.id).maybeSingle();
 if(membershipError||!membership)throw new Error('Nuk ke akses në këtë bisedë');
 const {error}=await client.from('messages').insert({conversation_id:conversationId,sender_id:user.id,body:body.trim()});
 if(error)throw new Error('Mesazhi nuk u dërgua');
 revalidatePath('/mesazhet/'+conversationId);
}
