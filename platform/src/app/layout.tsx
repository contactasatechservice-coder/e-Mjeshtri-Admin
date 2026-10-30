import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "e-Mjeshtri | Gjej mjeshtrin e duhur", description: "Publiko punë, gjej profesionistë dhe ofro shërbime në Shqipëri." };
export default function RootLayout({children}:{children:React.ReactNode}) {return <html lang="sq"><body>{children}</body></html>}
