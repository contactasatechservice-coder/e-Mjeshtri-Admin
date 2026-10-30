import type { Metadata } from "next";import SiteHeader from "@/components/site-header";import "./globals.css";
export const metadata:Metadata={title:"e-Mjeshtri | Gjej mjeshtrin e duhur",description:"Platformë për kërkesa pune dhe shërbime profesionale në Shqipëri."};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="sq"><body><SiteHeader/>{children}<footer>© e-Mjeshtri · Version demonstrimi</footer></body></html>}
