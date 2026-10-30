import Link from 'next/link';
import { requireRole } from '@/lib/server/require-role';
import { updateCitizenProfile } from '../actions';
export default async function CitizenProfilePage() {
 const {user,client}=await requireRole(['citizen']);
 const {data:profile,error}=await client.from('profiles').select('full_name,phone,city').eq('id',user.id).maybeSingle();
 return <main className="citizen-page"><div className="citizen-container"><Link href="/panel/qytetar">← Paneli im</Link><section className="citizen-feature" style={{maxWidth:720,margin:'24px auto'}}><h1>Profili im</h1>{error?<p role="alert">Profili nuk u ngarkua.</p>:<form action={updateCitizenProfile} className="citizen-form"><label htmlFor="full_name">Emri i plotë</label><input id="full_name" name="full_name" required minLength={2} maxLength={120} defaultValue={profile?.full_name ?? ''}/><label htmlFor="phone">Telefoni</label><input id="phone" name="phone" type="tel" maxLength={30} defaultValue={profile?.phone ?? ''}/><label htmlFor="city">Qyteti</label><input id="city" name="city" maxLength={100} defaultValue={profile?.city ?? ''}/><button type="submit">Ruaj ndryshimet</button></form>}</section></div></main>;
}
