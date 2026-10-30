import type {SVGProps} from "react";
const paths:Record<string,string>={
"layout-dashboard":"M3 3h8v8H3z M13 3h8v5h-8z M13 10h8v11h-8z M3 13h8v8H3z",
"users":"M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2 M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M22 21v-2a4 4 0 0 0-3-3.87 M16 3.13a4 4 0 0 1 0 7.75",
"wrench":"M14.7 6.3a5 5 0 0 0-6.4 6.4L3 18a2 2 0 0 0 3 3l5.3-5.3a5 5 0 0 0 6.4-6.4L14 13l-3-3z",
"building-2":"M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18 M2 22h20 M10 6h4 M10 10h4 M10 14h4 M10 18h4",
"briefcase-business":"M3 7h18v13H3z M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2 M3 12a20 20 0 0 0 18 0 M12 12v3",
"layers":"m12 2 9 5-9 5-9-5z m-9 10 9 5 9-5 M3 17l9 5 9-5",
"wallet":"M3 6h16a2 2 0 0 1 2 2v12H3a2 2 0 0 1-2-2V6a3 3 0 0 1 3-3h15 M16 13h6v4h-6a2 2 0 0 1 0-4z",
"package":"m12 2 9 5-9 5-9-5z M3 7v10l9 5 9-5V7 M12 12v10 M7.5 4.5l9 5",
"megaphone":"M3 11v3h4l11 5V6L7 11z M7 14l2 7h3l-2-6 M18 9a3 3 0 0 1 0 7",
"message-square":"M21 11.5a8.5 8.5 0 0 1-8.5 8.5H4l2-4a8.5 8.5 0 1 1 15-4.5z M8 10h9 M8 14h6",
"bell":"M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9 M10 21h4",
"chart-no-axes-column":"M5 20v-7h4v7 M11 20V4h4v16 M17 20v-10h4v10",
"shield-check":"m12 2 9 4v6c0 5-3.5 8-9 10-5.5-2-9-5-9-10V6z m-4 9 3 3 5-5",
"settings":"M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z M10 2h4l.6 3 2 .9 2.6-1.4 2.8 2.8-1.4 2.6.9 2 3 .6v4l-3 .6-.9 2 1.4 2.6-2.8 2.8-2.6-1.4-2 .9-.6 3h-4l-.6-3-2-.9-2.6 1.4-2.8-2.8 1.4-2.6-.9-2-3-.6v-4l3-.6.9-2-1.4-2.6 2.8-2.8 2.6 1.4 2-.9z"
};
export default function AdminIcon({name,...props}:SVGProps<SVGSVGElement>&{name:string}){return <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" {...props}><path d={paths[name]||paths["layout-dashboard"]}/></svg>}
