import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = {title:'e-Mjeshtri | Gjej profesionistin tënd',description:'Shërbime dhe vende pune në Shqipëri'};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="sq"><body>{children}</body></html>}
