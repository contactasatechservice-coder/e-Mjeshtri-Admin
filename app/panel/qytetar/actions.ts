'use server';
import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { requireRole } from '@/lib/server/require-role';

function required(value: FormDataEntryValue | null, label: string, max: number) {
  if (typeof value !== 'string' || value.trim().length < 2 || value.trim().length > max) throw new Error(label + ' nuk është i vlefshëm');
  return value.trim();
}
export async function createCitizenRequest(formData: FormData) {
  const {user,client} = await requireRole(['citizen']);
  const categoryId = formData.get('category_id');
  if (typeof categoryId !== 'string' || !/^[0-9a-f-]{36}$/i.test(categoryId)) throw new Error('Zgjidh një kategori');
  const title = required(formData.get('title'),'Titulli',120);
  const description = required(formData.get('description'),'Përshkrimi',2000);
  const city = formData.get('city');
  if (typeof city !== 'string' || city.length > 100) throw new Error('Qyteti nuk është i vlefshëm');
  const {data: category,error: categoryError} = await client.from('categories').select('id').eq('id',categoryId).eq('active',true).maybeSingle();
  if (categoryError || !category) throw new Error('Kategoria nuk është aktive');
  const {error} = await client.from('service_requests').insert({citizen_id:user.id,category_id:categoryId,title,description,city:city.trim() || null});
  if (error) throw new Error('Kërkesa nuk u ruajt. Provo përsëri.');
  revalidatePath('/panel/qytetar');
  redirect('/panel/qytetar');
}
export async function updateCitizenProfile(formData: FormData) {
  const {user,client} = await requireRole(['citizen']);
  const full_name = required(formData.get('full_name'),'Emri',120);
  const phone = formData.get('phone');
  const city = formData.get('city');
  if (typeof phone !== 'string' || phone.length > 30 || typeof city !== 'string' || city.length > 100) throw new Error('Të dhënat nuk janë të vlefshme');
  const {error} = await client.from('profiles').update({full_name,phone:phone.trim() || null,city:city.trim() || null}).eq('id',user.id);
  if (error) throw new Error('Profili nuk u përditësua.');
  revalidatePath('/panel/qytetar');
  redirect('/panel/qytetar');
}
