'use client';
import { useRouter } from 'next/navigation';
import { supabase } from '@/lib/supabase';

export function LogoutButton() {
  const router = useRouter();
  async function logout() {
    const { error } = await supabase().auth.signOut();
    if (error) return;
    router.replace('/hyrje');
    router.refresh();
  }
  return <button className="ghost" onClick={logout}>Dil</button>;
}
