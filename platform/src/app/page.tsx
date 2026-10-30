import Link from "next/link";
const roles=[
 {name:"Qytetar",href:"/qytetar",left:"3.3%",top:"46.8%",width:"45.6%",height:"23.6%"},
 {name:"Mjeshtër",href:"/mjeshter",left:"51.3%",top:"46.8%",width:"45.6%",height:"23.6%"},
 {name:"Kompani",href:"/per-kompanite",left:"3.3%",top:"71.6%",width:"45.6%",height:"23.8%"},
 {name:"Admin",href:"/hyrje?rol=admin",left:"51.3%",top:"71.6%",width:"45.6%",height:"23.8%"}
];
export default function Welcome(){
 return <main style={{minHeight:"100vh",background:"#f7faff",padding:"0 0 24px"}}>
 <div style={{position:"relative",maxWidth:1024,margin:"0 auto",lineHeight:0}}>
 <img src="/images/faqja-kryesore.png" alt="Mirë se vini në e-Mjeshtri. Zgjidh rolin tënd: Qytetar, Mjeshtër, Kompani ose Admin." width={1024} height={1536} style={{display:"block",width:"100%",height:"auto"}}/>
 {roles.map(role=><Link key={role.name} href={role.href} aria-label={"Vazhdo si "+role.name} title={"Vazhdo si "+role.name} style={{position:"absolute",left:role.left,top:role.top,width:role.width,height:role.height,display:"block",borderRadius:"4%",outlineOffset:-3}}><span className="sr-only">Vazhdo si {role.name}</span></Link>)}
 </div>
 </main>;
}