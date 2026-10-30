import type { ReactNode } from 'react';
export function CitizenCategoryIcon({ name }: { name: string }) {
 const shapes: Record<string, ReactNode> = {
  Hidraulik:<><path d="M4 14h16v4H4zM8 14V9a3 3 0 0 1 3-3h6M17 4v4M14 4h6"/></>,
  Elektricist:<path d="m13 2-9 12h7l-1 8 10-12h-7V2Z"/>,
  Lyerje:<><rect x="3" y="4" width="17" height="7" rx="2"/><path d="M20 7h2v6h-9v8m-2 0h4"/></>,
  'Ndërtim':<><rect x="2" y="5" width="20" height="14" rx="1"/><path d="M2 12h20M8 5v7m8 0v7"/></>,
  Klimatizim:<><rect x="2" y="5" width="20" height="10" rx="2"/><path d="M5 9h14M7 18c-1 1-1 2 0 3m5-3c-1 1-1 2 0 3m5-3c-1 1-1 2 0 3"/></>,
  Pastrim:<><path d="m15 3-5 12m-3-1 8 3-2 5-9-3 3-5Z"/></>,
 };
 return <svg viewBox="0 0 24 24" width="46" height="46" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">{shapes[name]}</svg>;
}
