import Link from 'next/link';
import {requireRole} from '@/lib/server/require-role';
import {sendMessage} from '../actions';
export default async function ConversationPage({params}:{params:Promise<{id:string}>}){
 const {id}=await params;
 const {user,client}=await requireRole(['citizen','worker','company']);
 if(!/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(id))return <main className="shell"><p>Bisedë e pavlefshme.</p></main>;
 const {data:membership}=await client.from('conversation_members').select('conversation_id').eq('conversation_id',id).eq('user_id',user.id).maybeSingle();
 if(!membership)return <main className="shell"><p>Nuk ke akses në këtë bisedë.</p></main>;
 const {data:messages,error}=await client.from('messages').select('id,sender_id,body,created_at').eq('conversation_id',id).order('created_at',{ascending:true}).limit(100);
 return <main className="shell"><header className="top"><Link href="/mesazhet" className="logo">← Mesazhet</Link></header><section className="auth" style={{maxWidth:780}}><h1>Biseda</h1>{error?<p role="alert">Mesazhet nuk u ngarkuan.</p>:<ol className="message-thread">{(messages??[]).map(message=><li key={message.id} className={message.sender_id===user.id?'mine':''}><p>{message.body}</p><small>{new Date(message.created_at).toLocaleString('sq-AL')}</small></li>)}</ol>}<form action={sendMessage} className="citizen-form"><input type="hidden" name="conversation_id" value={id}/><label htmlFor="message-body">Mesazhi yt</label><textarea id="message-body" name="body" maxLength={3000} rows={3} required/><button type="submit">Dërgo mesazhin</button></form></section></main>;
}
