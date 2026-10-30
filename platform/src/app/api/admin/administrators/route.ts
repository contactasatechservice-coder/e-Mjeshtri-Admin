import {NextRequest,NextResponse} from "next/server";
import {createClient} from "@supabase/supabase-js";
export const runtime="nodejs";
export async function GET(req:NextRequest){
const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,secret=process.env.SUPABASE_SERVICE_ROLE_KEY;
if(!url||!key||!secret)return NextResponse.json({error:"Mungon konfigurimi sekret i serverit."},{status:503});
const token=req.headers.get("authorization")?.replace(/^Bearer /,"");
if(!token)return NextResponse.json({error:"Kërkohet hyrja."},{status:401});
const {data:{user},error}=await createClient(url,key,{auth:{persistSession:false}}).auth.getUser(token);
if(error||user?.app_metadata?.em_admin!==true)return NextResponse.json({error:"Nuk ke autorizim."},{status:403});
const {data,error:failure}=await createClient(url,secret,{auth:{persistSession:false}}).auth.admin.listUsers({page:1,perPage:1000});
if(failure)return NextResponse.json({error:"Gabim në server."},{status:500});
return NextResponse.json({administrators:data.users.filter(u=>u.app_metadata?.em_admin===true).map(u=>({id:u.id,email:u.email??"",created_at:u.created_at}))},{headers:{"Cache-Control":"no-store"}});
}