'use server';

import { revalidatePath } from 'next/cache';
import { requireRole } from '@/lib/server/require-role';

export async function setCompanyVerification(formData: FormData): Promise<void> {
  const { client } = await requireRole(['super_admin']);
  const companyId = formData.get('companyId');
  const verified = formData.get('verified');
  if (typeof companyId !== 'string' || !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(companyId)) {
    throw new Error('ID e kompanise nuk eshte e vlefshme');
  }
  if (verified !== 'true' && verified !== 'false') {
    throw new Error('Statusi i kerkuar nuk eshte i vlefshem');
  }
  // This RPC re-checks super_admin from auth.uid() and writes the audit log
  // in the same database transaction. Never update verified from the browser.
  const { error } = await client.rpc('admin_set_company_verification', {
    p_company_id: companyId,
    p_verified: verified === 'true',
  });
  if (error) throw new Error('Verifikimi deshtoi. Kontrollo aktivizimin e funksionit te sigurt ne Supabase.');
  revalidatePath('/panel/admin');
}
