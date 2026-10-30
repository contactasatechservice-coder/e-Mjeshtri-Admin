import type { Metadata } from "next";
import SiteChrome from "@/components/site-chrome";
import "./globals.css";
export const metadata:Metadata={title:"e-Mjeshtri | Gjej mjeshtrin e duhur",description:"Gjej mjeshtra dhe shërbime profesionale në Shqipëri.",viewport:"width=device-width, initial-scale=1"};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="sq"><body><SiteChrome>{children}</SiteChrome></body></html>}