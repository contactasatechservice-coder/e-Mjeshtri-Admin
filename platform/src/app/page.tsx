import Link from "next/link";
const roles=[
 {name:"Qytetar",href:"/qytetar",left:"3.3%",top:"46.8%",width:"45.6%",height:"23.6%"},
 {name:"Mjeshtër",href:"/mjeshter",left:"51.3%",top:"46.8%",width:"45.6%",height:"23.6%"},
 {name:"Kompani",href:"/per-kompanite",left:"3.3%",top:"71.6%",width:"45.6%",height:"23.8%"},
 {name:"Admin",href:"/hyrje?rol=admin",left:"51.3%",top:"71.6%",width:"45.6%",height:"23.8%"}
];
export default function Welcome(){
 return <main className="welcome-page" >
 <div className="welcome-artboard">
 <img src="/images/faqja-kryesore.png" alt="Mirë se vini në e-Mjeshtri. Zgjidh rolin tënd: Qytetar, Mjeshtër, Kompani ose Admin." width={1024} height={1536} className="welcome-image"/>
 {roles.map(role=><Link key={role.name} href={role.href} aria-label={"Vazhdo si "+role.name} title={"Vazhdo si "+role.name} className="welcome-role-link" style={{position:"absolute",left:role.left,top:role.top,width:role.width,height:role.height,display:"block",borderRadius:"4%",outlineOffset:-3,WebkitTapHighlightColor:"transparent",background:"transparent"}}><span style={{position:"absolute",width:1,height:1,padding:0,margin:-1,overflow:"hidden",clip:"rect(0,0,0,0)",whiteSpace:"nowrap",border:0}}>Vazhdo si {role.name}</span></Link>)}
 </div>
 </main>;
}