"use client";
import {usePathname} from "next/navigation";
import SiteHeader from "@/components/site-header";
export default function SiteChrome({children}:{children:React.ReactNode}){
 const pathname=usePathname();
 if(pathname==="/")return <>{children}</>;
 return <><SiteHeader/>{children}<footer>© e-Mjeshtri · Version paraprak — profilet ilustrative</footer></>;
}