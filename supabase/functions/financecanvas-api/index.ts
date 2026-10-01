import { createClient } from "npm:@supabase/supabase-js@2.117.2";

const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};
const editable = new Set(["workspaces","profiles","institutions","accounts","transactions","merchant_aliases","loans","insurance_policies","assets","liabilities","investments","subscriptions","goals","watch_rules","data_freshness","households","household_members","profile_relationships","asset_owners","liability_owners","loan_borrowers","account_balances","credit_card_statements","budgets","recurring_items","financial_snapshots","imports","extracted_fields","confirmation_queue","income_sources","insurance_premiums","financial_preferences","recommendations","investment_allocation_targets"]);
const deletable = new Set(["profiles","institutions","accounts","transactions","merchant_aliases","loans","insurance_policies","assets","liabilities","investments","subscriptions","goals","watch_rules","households","household_members","profile_relationships","asset_owners","liability_owners","loan_borrowers","account_balances","credit_card_statements","budgets","recurring_items","financial_snapshots","imports","extracted_fields","confirmation_queue","income_sources","insurance_premiums","financial_preferences","recommendations","investment_allocation_targets"]);
const genericCreate = new Set(["institutions","account_owners","transaction_splits","merchant_aliases","loans","loan_payments","insurance_policies","assets","liabilities","investments","investment_transactions","subscriptions","goals","correction_memory","data_freshness","processing_consents","sensitive_data_events","privacy_requests","breach_incidents","households","household_members","profile_relationships","asset_owners","liability_owners","loan_borrowers","account_balances","credit_card_statements","budgets","recurring_items","financial_snapshots","imports","extracted_fields","confirmation_queue","income_sources","insurance_premiums","financial_preferences","recommendations","investment_allocation_targets"]);
const genericList = new Set(["institutions","account_owners","transaction_splits","merchant_aliases","loans","loan_payments","insurance_policies","assets","liabilities","investments","investment_transactions","subscriptions","goals","correction_memory","duplicate_reviews","audit_log","watch_rules","watch_findings","data_freshness","processing_consents","sensitive_data_events","privacy_requests","breach_incidents","security_events","households","household_members","profile_relationships","asset_owners","liability_owners","loan_borrowers","account_balances","credit_card_statements","budgets","recurring_items","financial_snapshots","imports","extracted_fields","confirmation_queue","income_sources","insurance_premiums","financial_preferences","recommendations","investment_allocation_targets"]);

function respond(body: unknown, status=200) {
  return new Response(JSON.stringify(body), {status, headers:{...cors,"content-type":"application/json; charset=utf-8"}});
}
function serverKey() {
  const modern=Deno.env.get("SUPABASE_SECRET_KEYS");
  if (modern) {
    const keys=JSON.parse(modern);
    const key=keys.default ?? Object.values(keys)[0];
    if (typeof key==="string" && key) return key;
  }
  const legacy=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  throw new Error("Supabase server secret unavailable");
}
async function sha256(v:string) {
  const d=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(v));
  return [...new Uint8Array(d)].map(x=>x.toString(16).padStart(2,"0")).join("");
}
function norm(v:unknown){return String(v??"").trim().toLowerCase().replace(/\s+/g," ")}
function reqFields(p:Record<string,any>, fs:string[]){for(const f of fs) if(p[f]===undefined||p[f]===null||p[f]==="") throw new Error("Missing required field: "+f)}
async function fp(t:Record<string,any>) {
  return sha256(JSON.stringify({
    workspace_id:norm(t.workspace_id), account_id:norm(t.account_id), posted_date:norm(t.posted_date),
    amount:Number(t.amount??0).toFixed(2), currency:String(t.currency??"INR").toUpperCase(),
    direction:norm(t.direction), reference:norm(t.transaction_reference), raw_description:norm(t.raw_description)
  }));
}
function words(v:unknown){return new Set(norm(v).split(/[^a-z0-9]+/).filter(x=>x.length>1))}
function sim(a:unknown,b:unknown){
  const x=words(a), y=words(b); if(!x.size&&!y.size)return 1;
  const i=[...x].filter(z=>y.has(z)).length; return i/new Set([...x,...y]).size;
}
function differences(a:Record<string,any>,b:Record<string,any>){
  const out:Record<string,any>={};
  for(const f of ["posted_date","transaction_date","amount","currency","direction","raw_description","merchant_normalized","transaction_reference","category","subcategory","purpose","profile_id","account_id"])
    if(JSON.stringify(a[f]??null)!==JSON.stringify(b[f]??null)) out[f]={existing:a[f]??null,incoming:b[f]??null};
  return out;
}
const forbiddenKey=/(^|_)(cvv|cvc|pin|upi_pin|otp|password|passcode|secret|private_key|seed|mnemonic|recovery_phrase|aadhaar|aadhar|vid|pan|passport|tax_id|card_number|full_card_number|account_number|api_key|access_token|refresh_token)($|_)/i;
function luhnDigits(raw:string){
  const digits=raw.replace(/\D/g,""); if(digits.length<13||digits.length>19)return false;
  let sum=0, alt=false; for(let i=digits.length-1;i>=0;i--){let n=Number(digits[i]);if(alt){n*=2;if(n>9)n-=9}sum+=n;alt=!alt} return sum%10===0;
}
function redactCardNumbers(s:string){
  return s.replace(/(?:\d[ -]?){13,19}/g,(m)=>luhnDigits(m)?("[REDACTED_CARD_LAST4_"+m.replace(/\D/g,"").slice(-4)+"]"):m);
}
function sanitizeString(s:string){
  const critical=/(?:cvv|cvc|otp|upi[ _-]?pin|atm[ _-]?pin|password|passcode|private[ _-]?key|seed[ _-]?phrase|recovery[ _-]?phrase|api[ _-]?key|access[ _-]?token|refresh[ _-]?token)\s*[:=]\s*\S+/i;
  const govt=/(?:aadhaar|aadhar|vid|pan|passport)\s*[:=]\s*[A-Z0-9 -]{6,20}|\b[A-Z]{5}[0-9]{4}[A-Z]\b/i;
  const acct=/(?:account(?:[ _-]?number)?|a\/c)\s*[:=]\s*\d{6,20}/i;
  if(critical.test(s)){
    const e:any=new Error("Critical authentication/payment secret detected. FinanceCanvas will not persist this value.");
    e.status=422; e.code="CRITICAL_SECRET_DETECTED"; throw e;
  }
  if(govt.test(s)){
    const e:any=new Error("High-risk government identifier detected. FinanceCanvas v0.1 does not persist this identifier.");
    e.status=422; e.code="HIGH_RISK_IDENTIFIER_DETECTED"; throw e;
  }
  if(acct.test(s)){
    const e:any=new Error("Full account number detected. Store only a masked identifier or final four digits.");
    e.status=422; e.code="FULL_ACCOUNT_NUMBER_DETECTED"; throw e;
  }
  return redactCardNumbers(s);
}
function sanitizeValue(v:any,path="root"):any{
  if(v===null||v===undefined)return v;
  if(typeof v==="string")return sanitizeString(v);
  if(Array.isArray(v))return v.map((x,i)=>sanitizeValue(x,path+"["+i+"]"));
  if(typeof v==="object"){
    const out:Record<string,any>={};
    for(const [k,val] of Object.entries(v)){
      if(forbiddenKey.test(k)&&val!==null&&val!==undefined&&String(val)!=="") {
        const e:any=new Error("High-risk secret/identifier field is not allowed in FinanceCanvas persistent storage: "+k);
        e.status=422; e.code="SENSITIVE_SECRET_NOT_ALLOWED"; e.field=k; throw e;
      }
      out[k]=sanitizeValue(val,path+"."+k);
    }
    return out;
  }
  return v;
}
function auditSafe(v:any):any{
  const x=sanitizeValue(v);
  if(!x||typeof x!=="object"||Array.isArray(x))return x;
  const out={...x};
  for(const k of ["raw_values","normalized_values","raw_description","transaction_reference","metadata"]) if(k in out) delete out[k];
  return out;
}
async function auth(req:Request,db:any){
  const h=req.headers.get("authorization")??"";
  const token=h.startsWith("Bearer ")?h.slice(7).trim():"";
  if(!token.startsWith("fc_")) throw Object.assign(new Error("Unauthorized"),{status:401});
  const hash=await sha256(token);
  const {data,error}=await db.from("financecanvas_api_keys").select("id,workspace_id,scopes").eq("key_hash",hash).eq("active",true).is("revoked_at",null).maybeSingle();
  if(error||!data) throw Object.assign(new Error("Unauthorized"),{status:401});
  await db.from("financecanvas_api_keys").update({last_used_at:new Date().toISOString()}).eq("id",data.id);
  return data;
}
function requiredScope(op:string){
  if(["create_api_key","revoke_api_key"].includes(op)) return "admin";
  if(["export_workspace_json","export_workspace_csv"].includes(op)) return "export";
  if(["create_watch_rule","run_watch_checks"].includes(op)) return "watch";
  if(["initialize_workspace","create_profile","create_account","create_record","commit_transactions","request_edit","request_delete","confirm_pending_operation","request_workspace_erasure","confirm_workspace_erasure"].includes(op)) return "write";
  return "read";
}
function csvEscape(v:any){
  if(v===null||v===undefined)return "";
  const s=typeof v==="object"?JSON.stringify(v):String(v);
  return /[",\n\r]/.test(s)?'"'+s.replace(/"/g,'""')+'"':s;
}
function rowsToCsv(rows:any[]){
  if(!rows.length)return "";
  const headers=[...new Set(rows.flatMap(r=>Object.keys(r)))];
  return headers.map(csvEscape).join(",")+"\n"+rows.map(r=>headers.map(h=>csvEscape(r[h])).join(",")).join("\n");
}
async function assertIdsInWorkspace(db:any,table:string,ids:any[],workspaceId:string){
  const unique=[...new Set(ids.filter(Boolean).map(String))];
  if(!unique.length)return;
  const {data,error}=await db.from(table).select("id").eq("workspace_id",workspaceId).in("id",unique);
  if(error)throw error;
  const found=new Set((data??[]).map((x:any)=>String(x.id)));
  const missing=unique.filter(id=>!found.has(id));
  if(missing.length)throw Object.assign(new Error("Referenced "+table+" record does not belong to this workspace"),{status:403,code:"CROSS_WORKSPACE_REFERENCE"});
}
async function validateGenericRefs(db:any,table:string,row:any,ws:string){
  const one=async(t:string,id:any)=>assertIdsInWorkspace(db,t,[id],ws);
  if(table==="transaction_splits"){await one("transactions",row.transaction_id);await one("profiles",row.profile_id);}
  if(table==="loans"){await one("profiles",row.profile_id);await one("institutions",row.institution_id);}
  if(table==="loan_payments"){await one("loans",row.loan_id);await one("transactions",row.transaction_id);}
  if(table==="insurance_policies"){await one("profiles",row.profile_id);await one("institutions",row.institution_id);}
  if(["assets","liabilities","subscriptions","goals","processing_consents","privacy_requests","sensitive_data_events","budgets","financial_snapshots"].includes(table))await one("profiles",row.profile_id);
  if(table==="investments"){await one("profiles",row.profile_id);await one("accounts",row.account_id);}
  if(table==="investment_transactions"){await one("investments",row.investment_id);await one("transactions",row.transaction_id);}
  if(table==="data_freshness")await one("accounts",row.account_id);
  if(table==="household_members"){await one("households",row.household_id);await one("profiles",row.profile_id);}
  if(table==="profile_relationships"){await assertIdsInWorkspace(db,"profiles",[row.profile_id,row.related_profile_id],ws);}
  if(table==="asset_owners"){await one("assets",row.asset_id);await one("profiles",row.profile_id);}
  if(table==="liability_owners"){await one("liabilities",row.liability_id);await one("profiles",row.profile_id);}
  if(table==="loan_borrowers"){await one("loans",row.loan_id);await one("profiles",row.profile_id);}
  if(["account_balances","credit_card_statements"].includes(table)){await one("accounts",row.account_id);await one("imports",row.import_id);}
  if(table==="recurring_items"){await one("profiles",row.profile_id);await one("accounts",row.account_id);}
  if(table==="imports"){await one("profiles",row.profile_id);await one("accounts",row.account_id);}
  if(["extracted_fields","confirmation_queue"].includes(table))await one("imports",row.import_id);
  if(table==="income_sources"){await one("profiles",row.profile_id);await one("accounts",row.account_id);}
  if(table==="insurance_premiums"){await one("insurance_policies",row.policy_id);await one("transactions",row.transaction_id);}
  if(["financial_preferences","recommendations"].includes(table))await one("profiles",row.profile_id);
  if(table==="investment_allocation_targets"){await one("profiles",row.profile_id);await one("investments",row.investment_id);}
}
function median(nums:number[]){
  if(!nums.length)return 0;
  const a=[...nums].sort((x,y)=>x-y), m=Math.floor(a.length/2);
  return a.length%2?a[m]:(a[m-1]+a[m])/2;
}
function daysBetween(a:string,b:string){
  return Math.round((new Date(b+"T00:00:00Z").getTime()-new Date(a+"T00:00:00Z").getTime())/86400000);
}
function txnDelta(accountType:string,direction:string,amount:number){
  if(accountType==="credit_card") return direction==="debit"?amount:direction==="credit"?-amount:0;
  return direction==="credit"?amount:direction==="debit"?-amount:0;
}
async function nearMatches(db:any, ws:string, t:Record<string,any>) {
  const d=new Date(t.posted_date+"T00:00:00Z"), lo=new Date(d), hi=new Date(d);
  lo.setUTCDate(lo.getUTCDate()-3); hi.setUTCDate(hi.getUTCDate()+3);
  const {data,error}=await db.from("transactions").select("*").eq("workspace_id",ws).eq("account_id",t.account_id)
    .eq("currency",String(t.currency??"INR").toUpperCase()).eq("direction",t.direction).eq("amount",t.amount)
    .gte("posted_date",lo.toISOString().slice(0,10)).lte("posted_date",hi.toISOString().slice(0,10)).is("deleted_at",null).limit(20);
  if(error) throw error;
  return (data??[]).filter((x:any)=>sim(x.merchant_normalized??x.raw_description,t.merchant_normalized??t.raw_description)>=0.5);
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response("ok",{headers:cors});
  if(req.method!=="POST") return respond({error:"POST required"},405);
  try {
    const db=createClient(Deno.env.get("SUPABASE_URL")!,serverKey(),{auth:{persistSession:false,autoRefreshToken:false}});
    const identity=await auth(req,db);
    const body=await req.json(), op=String(body.operation??""), p=sanitizeValue((body.payload??{}) as Record<string,any>);
    const need=requiredScope(op);
    if(!identity.scopes?.includes(need) && !identity.scopes?.includes("admin")) throw Object.assign(new Error("API key lacks required scope: "+need),{status:403});
    if(identity.workspace_id){
      if(op==="initialization_status"){
        p.workspace_id=identity.workspace_id;
      } else if(p.workspace_id && String(p.workspace_id)!==String(identity.workspace_id)){
        throw Object.assign(new Error("API key is scoped to a different workspace"),{status:403});
      } else if(!p.workspace_id && !["create_api_key","revoke_api_key"].includes(op)){
        p.workspace_id=identity.workspace_id;
      }
    }

    if(op==="initialization_status"){
      let q=db.from("workspaces").select("id,name,base_currency,is_default,initialized").order("created_at");
      if(p.workspace_id) q=q.eq("id",p.workspace_id);
      const {data,error}=await q;
      if(error)throw error; return respond({initialized:(data?.length??0)>0,workspaces:data??[]});
    }
    if(op==="initialize_workspace"){
      const useDefault=Boolean(p.use_default), name=useDefault?"Personal Workspace":String(p.name??"").trim();
      if(!name)throw new Error("Workspace name required unless use_default=true");
      const {data:w,error}=await db.from("workspaces").insert({name,base_currency:String(p.base_currency??"INR").toUpperCase(),is_default:useDefault}).select().single();
      if(error)throw error;
      let profile=null;
      if(p.first_profile_name){const r=await db.from("profiles").insert({workspace_id:w.id,display_name:String(p.first_profile_name)}).select().single();if(r.error)throw r.error;profile=r.data}
      await db.from("audit_log").insert({workspace_id:w.id,action:"initialize_workspace",target_table:"workspaces",target_id:w.id,after_snapshot:w});
      return respond({workspace:w,profile});
    }
    if(op==="create_api_key"){
      const raw=new Uint8Array(36);crypto.getRandomValues(raw);
      const token="fc_"+btoa(String.fromCharCode(...raw)).replace(/\+/g,"-").replace(/\//g,"_").replace(/=+$/,"");
      const scopes=Array.isArray(p.scopes)&&p.scopes.length?p.scopes:["read","write","watch","export"];
      const {data,error}=await db.from("financecanvas_api_keys").insert({label:String(p.label??"rotated"),key_hash:await sha256(token),workspace_id:p.workspace_id??null,scopes}).select("id,label,workspace_id,scopes,created_at").single();
      if(error)throw error;return respond({api_key:token,key:data,note:"Returned once; store outside source control."});
    }
    if(op==="revoke_api_key"){
      reqFields(p,["key_id"]);const {data,error}=await db.from("financecanvas_api_keys").update({active:false,revoked_at:new Date().toISOString()}).eq("id",p.key_id).select("id,label,active,revoked_at").single();
      if(error)throw error;return respond({revoked:data});
    }
    if(op==="list_profiles"){
      reqFields(p,["workspace_id"]);const {data,error}=await db.from("profiles").select("*").eq("workspace_id",p.workspace_id).is("deleted_at",null).order("created_at");
      if(error)throw error;return respond({profiles:data??[]});
    }
    if(op==="create_profile"){
      reqFields(p,["workspace_id","display_name"]);
      const row={workspace_id:p.workspace_id,display_name:p.display_name,relationship:p.relationship??null,is_household:Boolean(p.is_household)};
      const {data,error}=await db.from("profiles").insert(row).select().single();if(error)throw error;
      await db.from("audit_log").insert({workspace_id:p.workspace_id,action:"create_profile",target_table:"profiles",target_id:data.id,after_snapshot:auditSafe(data)});
      return respond({profile:data});
    }
    if(op==="list_accounts"){
      reqFields(p,["workspace_id"]);let q=db.from("accounts").select("*").eq("workspace_id",p.workspace_id).is("deleted_at",null).order("name");
      if(p.account_type)q=q.eq("account_type",p.account_type);const {data,error}=await q;if(error)throw error;return respond({accounts:data??[]});
    }
    if(op==="create_account"){
      reqFields(p,["workspace_id","name","account_type"]);
      if(p.identifier_last4 && !/^\d{1,4}$/.test(String(p.identifier_last4))) throw new Error("identifier_last4 must contain at most the final 4 digits");
      await assertIdsInWorkspace(db,"institutions",[p.institution_id],p.workspace_id);
      const row={workspace_id:p.workspace_id,institution_id:p.institution_id??null,name:p.name,account_type:p.account_type,currency:String(p.currency??"INR").toUpperCase(),identifier_last4:p.identifier_last4??null,current_balance:p.current_balance??null,balance_as_of:p.balance_as_of??null,credit_limit:p.credit_limit??null,annual_fee:p.annual_fee??null,annual_fee_waiver_spend:p.annual_fee_waiver_spend??null,annual_fee_next_date:p.annual_fee_next_date??null,metadata:sanitizeValue(p.metadata??{})};
      const {data,error}=await db.from("accounts").insert(row).select().single();if(error)throw error;
      await db.from("audit_log").insert({workspace_id:p.workspace_id,action:"create_account",target_table:"accounts",target_id:data.id,after_snapshot:auditSafe(data)});
      return respond({account:data});
    }
    if(op==="create_record"){
      reqFields(p,["workspace_id","table","record"]);
      if(!genericCreate.has(String(p.table))) throw new Error("Table not creatable through generic FinanceCanvas API");
      const clean={...(p.record??{})};
      delete clean.id; delete clean.created_at; delete clean.updated_at; delete clean.deleted_at;
      if(p.table==="extracted_fields" && forbiddenKey.test(String(clean.field_key??""))){
        throw Object.assign(new Error("Sensitive identifier/secret fields are not allowed in persisted extracted fields"),{status:422,code:"SENSITIVE_FIELD_NOT_ALLOWED"});
      }
      if(p.table==="account_owners"){
        reqFields(clean,["account_id","profile_id"]);
        const a=await db.from("accounts").select("id").eq("id",clean.account_id).eq("workspace_id",p.workspace_id).single(); if(a.error) throw a.error;
        const pr=await db.from("profiles").select("id").eq("id",clean.profile_id).eq("workspace_id",p.workspace_id).single(); if(pr.error) throw pr.error;
      } else {
        clean.workspace_id=p.workspace_id;
        await validateGenericRefs(db,String(p.table),clean,p.workspace_id);
      }
      const r=await db.from(String(p.table)).insert(clean).select().single(); if(r.error) throw r.error;
      await db.from("audit_log").insert({workspace_id:p.workspace_id,action:"create_"+p.table,target_table:p.table,target_id:r.data.id??null,after_snapshot:auditSafe(r.data)});
      return respond({record:r.data});
    }
    if(op==="list_records"){
      reqFields(p,["workspace_id","table"]);
      if(!genericList.has(String(p.table))) throw new Error("Table not listable through generic FinanceCanvas API");
      let q;
      if(p.table==="account_owners"){
        q=db.from("account_owners").select("*,accounts!inner(workspace_id)").eq("accounts.workspace_id",p.workspace_id);
      } else {
        q=db.from(String(p.table)).select("*").eq("workspace_id",p.workspace_id);
      }
      const r=await q.limit(Math.min(Number(p.limit??200),500)); if(r.error) throw r.error;
      return respond({records:r.data??[]});
    }
    if(op==="preview_transaction_import"){
      reqFields(p,["workspace_id","transactions"]);const results=[];
      const previewRows=p.transactions as Record<string,any>[];
      await assertIdsInWorkspace(db,"accounts",previewRows.map(x=>x.account_id),p.workspace_id);
      await assertIdsInWorkspace(db,"profiles",previewRows.map(x=>x.profile_id),p.workspace_id);
      await assertIdsInWorkspace(db,"imports",previewRows.map(x=>x.import_id),p.workspace_id);
      for(const src of previewRows){
        const t={...src,workspace_id:p.workspace_id};reqFields(t,["account_id","posted_date","amount","direction"]);const base=await fp(t);
        const ex=await db.from("transactions").select("*").eq("workspace_id",p.workspace_id).eq("base_fingerprint",base).is("deleted_at",null).limit(1);if(ex.error)throw ex.error;
        if(ex.data?.length){results.push({client_id:src.client_id??null,status:"exact_duplicate",base_fingerprint:base,existing:ex.data[0],difference:differences(ex.data[0],t)});continue}
        const near=await nearMatches(db,p.workspace_id,t);
        if(near.length)results.push({client_id:src.client_id??null,status:"near_duplicate",base_fingerprint:base,matches:near.map((x:any)=>({existing:x,difference:differences(x,t)}))});
        else results.push({client_id:src.client_id??null,status:"ready",base_fingerprint:base});
      }
      return respond({results});
    }
    if(op==="commit_transactions"){
      reqFields(p,["workspace_id","transactions","final_confirmation"]);
      if(p.final_confirmation!==true)return respond({error:"Final user confirmation is required before commit."},409);

      const resolutions=new Map((p.duplicate_resolutions??[]).map((r:any)=>[String(r.client_id),r]));
      const commitRows=p.transactions as Record<string,any>[];
      await assertIdsInWorkspace(db,"accounts",commitRows.map(x=>x.account_id),p.workspace_id);
      await assertIdsInWorkspace(db,"profiles",commitRows.map(x=>x.profile_id),p.workspace_id);
      await assertIdsInWorkspace(db,"imports",commitRows.map(x=>x.import_id),p.workspace_id);

      const prepared:any[]=[],reviews:any[]=[],skipped:any[]=[],conflicts:any[]=[];

      for(const src of commitRows){
        const t={...src,workspace_id:p.workspace_id}, client=String(src.client_id??"");
        reqFields(t,["account_id","posted_date","amount","direction"]);
        const base=await fp(t);
        const ex=await db.from("transactions").select("*").eq("workspace_id",p.workspace_id).eq("base_fingerprint",base).is("deleted_at",null).limit(1);
        if(ex.error)throw ex.error;

        let fingerprint=base, duplicateOf=null, overrideReason=null;

        if(ex.data?.length){
          const existing=ex.data[0], r:any=resolutions.get(client);
          if(!r){conflicts.push({client_id:client,type:"exact",existing});continue;}
          if(["skip","keep_existing","cancel"].includes(r.decision)){
            reviews.push({existing_transaction_id:existing.id,incoming_fingerprint:base,duplicate_type:"exact",decision:r.decision==="cancel"?"cancel":"skip",reason:r.reason??null,incoming_snapshot:auditSafe(t),difference:differences(existing,t)});
            skipped.push({client_id:client,reason:r.decision});continue;
          }
          if(r.decision!=="add_separate"||!String(r.reason??"").trim()){
            conflicts.push({client_id:client,type:"exact",message:"add_separate requires a reason"});continue;
          }
          duplicateOf=existing.id;
          overrideReason=String(r.reason).trim();
          fingerprint=await sha256(base+"|override|"+overrideReason+"|"+crypto.randomUUID());
          reviews.push({existing_transaction_id:duplicateOf,incoming_fingerprint:base,duplicate_type:"exact",decision:"add_separate",reason:overrideReason,incoming_snapshot:auditSafe(t),difference:differences(existing,t)});
        } else {
          const near=await nearMatches(db,p.workspace_id,t);
          if(near.length){
            const existing=near[0], r:any=resolutions.get(client);
            if(!r){conflicts.push({client_id:client,type:"near",matches:near.map((x:any)=>({existing:x,difference:differences(x,t)}))});continue;}
            if(["skip","keep_existing","cancel"].includes(r.decision)){
              reviews.push({existing_transaction_id:existing.id,incoming_fingerprint:base,duplicate_type:"near",decision:r.decision==="cancel"?"cancel":"keep_existing",reason:r.reason??null,incoming_snapshot:auditSafe(t),difference:differences(existing,t)});
              skipped.push({client_id:client,reason:r.decision});continue;
            }
            if(r.decision==="update_existing"){
              conflicts.push({client_id:client,type:"near",message:"Use request_edit then confirm_pending_operation to update existing.",existing});continue;
            }
            if(r.decision!=="add_separate"||!String(r.reason??"").trim()){
              conflicts.push({client_id:client,type:"near",message:"add_separate requires a reason"});continue;
            }
            duplicateOf=existing.id;
            overrideReason=String(r.reason).trim();
            reviews.push({existing_transaction_id:duplicateOf,incoming_fingerprint:base,duplicate_type:"near",decision:"add_separate",reason:overrideReason,incoming_snapshot:auditSafe(t),difference:differences(existing,t)});
          }
        }

        prepared.push({
          workspace_id:p.workspace_id,
          profile_id:t.profile_id??null,
          account_id:t.account_id,
          import_id:t.import_id??null,
          posted_date:t.posted_date,
          transaction_date:t.transaction_date??null,
          amount:t.amount,
          currency:String(t.currency??"INR").toUpperCase(),
          direction:t.direction,
          raw_description:t.raw_description??null,
          merchant_normalized:t.merchant_normalized??null,
          transaction_reference:t.transaction_reference??null,
          category:t.category??null,
          subcategory:t.subcategory??null,
          purpose:t.purpose??null,
          confidence:t.confidence??null,
          confirmation_status:t.confirmation_status??"confirmed",
          balance_after:t.balance_after??null,
          source_sequence:t.source_sequence??null,
          raw_values:t.raw_values??{},
          normalized_values:t.normalized_values??{},
          base_fingerprint:base,
          fingerprint,
          duplicate_of_transaction_id:duplicateOf,
          duplicate_override_reason:overrideReason,
          duplicate_override_at:overrideReason?new Date().toISOString():null
        });
      }

      if(conflicts.length)return respond({inserted:[],skipped,conflicts,atomic_commit:false},409);

      const rpc=await db.rpc("financecanvas_commit_transaction_batch",{p_workspace_id:p.workspace_id,p_rows:prepared,p_reviews:reviews});
      if(rpc.error)throw rpc.error;
      const ids=(rpc.data?.inserted_ids??[]) as string[];
      let inserted:any[]=[];
      if(ids.length){
        const q=await db.from("transactions").select("*").eq("workspace_id",p.workspace_id).in("id",ids);
        if(q.error)throw q.error; inserted=q.data??[];
      }
      return respond({inserted,skipped,conflicts:[],atomic_commit:true,batch_result:rpc.data});
    }
    if(op==="search_transactions"){
      reqFields(p,["workspace_id"]);let q=db.from("transactions").select("*").eq("workspace_id",p.workspace_id).is("deleted_at",null).order("posted_date",{ascending:false}).limit(Math.min(Number(p.limit??100),500));
      if(p.account_id)q=q.eq("account_id",p.account_id);if(p.profile_id)q=q.eq("profile_id",p.profile_id);if(p.from_date)q=q.gte("posted_date",p.from_date);if(p.to_date)q=q.lte("posted_date",p.to_date);if(p.category)q=q.eq("category",p.category);
      const {data,error}=await q;if(error)throw error;return respond({transactions:data??[]});
    }
    if(op==="request_edit"){
      reqFields(p,["workspace_id","table","record_id","patch"]);if(!editable.has(String(p.table)))throw new Error("Table not editable through FinanceCanvas API");
      let q=db.from(String(p.table)).select("*").eq("id",p.record_id);q=p.table==="workspaces"?q.eq("id",p.workspace_id):q.eq("workspace_id",p.workspace_id);
      const {data:before,error}=await q.single();if(error)throw error;
      const r=await db.from("pending_operations").insert({workspace_id:p.workspace_id,operation_type:"edit_record",target_table:p.table,target_id:p.record_id,requested_change:p.patch,before_snapshot:before,reason:p.reason??null}).select().single();if(r.error)throw r.error;
      return respond({pending_operation:r.data,before,proposed:{...before,...p.patch},confirmation_required:true});
    }
    if(op==="request_delete"){
      reqFields(p,["workspace_id","table","record_id","delete_type"]);if(!deletable.has(String(p.table)))throw new Error("Table not deletable through FinanceCanvas API");if(!["soft","permanent"].includes(p.delete_type))throw new Error("delete_type must be soft or permanent");
      const r=await db.from(String(p.table)).select("*").eq("workspace_id",p.workspace_id).eq("id",p.record_id).single();if(r.error)throw r.error;
      const typ=p.delete_type==="permanent"?"permanent_delete_record":"soft_delete_record";
      const x=await db.from("pending_operations").insert({workspace_id:p.workspace_id,operation_type:typ,target_table:p.table,target_id:p.record_id,before_snapshot:r.data,reason:p.reason??null}).select().single();if(x.error)throw x.error;
      return respond({pending_operation:x.data,before:r.data,confirmation_required:true});
    }
    if(op==="confirm_pending_operation"){
      reqFields(p,["workspace_id","operation_id","confirmed"]);const r=await db.from("pending_operations").select("*").eq("workspace_id",p.workspace_id).eq("id",p.operation_id).single();if(r.error)throw r.error;const o=r.data;
      if(o.status!=="pending")return respond({error:"Operation is "+o.status},409);
      if(new Date(o.expires_at).getTime()<Date.now()){await db.from("pending_operations").update({status:"expired"}).eq("id",o.id);return respond({error:"Pending operation expired"},409)}
      if(p.confirmed!==true){await db.from("pending_operations").update({status:"cancelled"}).eq("id",o.id);return respond({cancelled:true})}
      if(!editable.has(o.target_table)&&!deletable.has(o.target_table))throw new Error("Non-whitelisted target table");
      if(o.operation_type==="edit_record"){
        let q=db.from(o.target_table).update(o.requested_change).eq("id",o.target_id);if(o.target_table!=="workspaces")q=q.eq("workspace_id",p.workspace_id);
        const u=await q.select().single();if(u.error)throw u.error;
        await db.from("audit_log").insert({workspace_id:p.workspace_id,action:"edit_"+o.target_table,target_table:o.target_table,target_id:o.target_id,before_snapshot:auditSafe(o.before_snapshot),after_snapshot:auditSafe(u.data),reason:o.reason});
        await db.from("pending_operations").update({status:"applied",applied_at:new Date().toISOString()}).eq("id",o.id);return respond({applied:true,record:u.data});
      }
      if(o.operation_type==="soft_delete_record"){
        const patch=o.target_table==="watch_rules"?{enabled:false}:{deleted_at:new Date().toISOString()};
        const u=await db.from(o.target_table).update(patch).eq("id",o.target_id).eq("workspace_id",p.workspace_id).select().single();if(u.error)throw u.error;
        await db.from("audit_log").insert({workspace_id:p.workspace_id,action:"soft_delete_"+o.target_table,target_table:o.target_table,target_id:o.target_id,before_snapshot:auditSafe(o.before_snapshot),after_snapshot:auditSafe(u.data),reason:o.reason});
        await db.from("pending_operations").update({status:"applied",applied_at:new Date().toISOString()}).eq("id",o.id);return respond({applied:true,record:u.data});
      }
      if(o.operation_type==="permanent_delete_record"){
        const d=await db.from(o.target_table).delete().eq("id",o.target_id).eq("workspace_id",p.workspace_id);if(d.error)throw d.error;
        await db.from("audit_log").insert({workspace_id:p.workspace_id,action:"permanent_delete_"+o.target_table,target_table:o.target_table,target_id:o.target_id,before_snapshot:{id:o.target_id},reason:o.reason,metadata:{data_minimized:true}});
        await db.from("pending_operations").update({status:"applied",applied_at:new Date().toISOString()}).eq("id",o.id);return respond({applied:true});
      }
    }
    if(op==="get_financial_summary"){
      reqFields(p,["workspace_id"]);const ws=p.workspace_id;
      const [a,l,ac,t,bg,ri,sn]=await Promise.all([
        db.from("assets").select("value,currency").eq("workspace_id",ws).is("deleted_at",null),
        db.from("liabilities").select("outstanding_amount,currency").eq("workspace_id",ws).is("deleted_at",null),
        db.from("accounts").select("current_balance,currency,balance_as_of").eq("workspace_id",ws).is("deleted_at",null),
        db.from("transactions").select("amount,direction,category,posted_date,currency").eq("workspace_id",ws).is("deleted_at",null),
        db.from("budgets").select("*").eq("workspace_id",ws).is("deleted_at",null).eq("status","active"),
        db.from("recurring_items").select("*").eq("workspace_id",ws).is("deleted_at",null).eq("enabled",true),
        db.from("financial_snapshots").select("*").eq("workspace_id",ws).is("deleted_at",null).order("snapshot_date",{ascending:false}).limit(24)
      ]);
      for(const r of [a,l,ac,t,bg,ri,sn])if(r.error)throw r.error;
      return respond({assets:a.data??[],liabilities:l.data??[],accounts:ac.data??[],transactions:t.data??[],budgets:bg.data??[],recurring_items:ri.data??[],financial_snapshots:sn.data??[],note:"Calculate totals deterministically and do not combine currencies without an explicit FX source."});
    }
    if(op==="create_watch_rule"){
      reqFields(p,["workspace_id","name","rule_type"]);await assertIdsInWorkspace(db,"profiles",[p.profile_id],p.workspace_id);const row={workspace_id:p.workspace_id,profile_id:p.profile_id??null,name:p.name,rule_type:p.rule_type,cadence:p.cadence??null,severity:p.severity??"notice",configuration:p.configuration??{},enabled:p.enabled??true};
      const r=await db.from("watch_rules").insert(row).select().single();if(r.error)throw r.error;await db.from("audit_log").insert({workspace_id:p.workspace_id,action:"create_watch_rule",target_table:"watch_rules",target_id:r.data.id,after_snapshot:auditSafe(r.data)});return respond({watch_rule:r.data});
    }
    if(op==="list_watch_rules"){
      reqFields(p,["workspace_id"]);const r=await db.from("watch_rules").select("*").eq("workspace_id",p.workspace_id).order("created_at",{ascending:false});if(r.error)throw r.error;return respond({watch_rules:r.data??[]});
    }
    if(op==="run_watch_checks"){
      reqFields(p,["workspace_id"]);
      const ws=p.workspace_id;
      const days=Math.max(1,Math.min(Number(p.lookback_days??35),365));
      const now=new Date();
      const d=new Date(now); d.setUTCDate(d.getUTCDate()-days);
      const since=d.toISOString().slice(0,10);
      const dayDiff=(dateStr:string)=>Math.floor((new Date(dateStr+"T00:00:00Z").getTime()-new Date(now.toISOString().slice(0,10)+"T00:00:00Z").getTime())/86400000);

      const [rr,tr,fr,cc,ins,goals,budgets,recurring,investments,accounts]=await Promise.all([
        db.from("watch_rules").select("*").eq("workspace_id",ws).eq("enabled",true),
        db.from("transactions").select("*").eq("workspace_id",ws).is("deleted_at",null).gte("posted_date",since).order("posted_date",{ascending:false}).limit(5000),
        db.from("data_freshness").select("*,accounts(name,account_type)").eq("workspace_id",ws),
        db.from("credit_card_statements").select("*").eq("workspace_id",ws).is("deleted_at",null),
        db.from("insurance_policies").select("*").eq("workspace_id",ws).is("deleted_at",null),
        db.from("goals").select("*").eq("workspace_id",ws).is("deleted_at",null).eq("status","active"),
        db.from("budgets").select("*").eq("workspace_id",ws).is("deleted_at",null).eq("status","active"),
        db.from("recurring_items").select("*").eq("workspace_id",ws).is("deleted_at",null).eq("enabled",true),
        db.from("investments").select("*").eq("workspace_id",ws).is("deleted_at",null),
        db.from("accounts").select("*").eq("workspace_id",ws).is("deleted_at",null)
      ]);
      for(const r of [rr,tr,fr,cc,ins,goals,budgets,recurring,investments,accounts])if(r.error)throw r.error;
      const tx=tr.data??[], findings:any[]=[];
      const add=async(f:any)=>findings.push({...f,workspace_id:ws,finding_fingerprint:await sha256(JSON.stringify([ws,f.watch_rule_id??null,f.finding_type,f.transaction_id??null,f.evidence??{}]))});

      for(const rule of rr.data??[]){
        const cfg=rule.configuration??{};

        if(rule.rule_type==="fee_watch"){
          const re=/(annual fee|joining fee|late fee|interest|finance charge|forex|markup|surcharge|cash advance|over.?limit|processing fee|convenience fee|gst.*fee)/i;
          for(const t of tx){
            const text=[t.category,t.subcategory,t.raw_description,t.merchant_normalized].join(" ");
            if(re.test(text))await add({watch_rule_id:rule.id,profile_id:t.profile_id,transaction_id:t.id,finding_type:"possible_fee",severity:rule.severity??"warning",title:"Possible fee/charge: "+t.amount+" "+t.currency,explanation:"This transaction contains wording commonly associated with a fee, interest, markup, or surcharge. Verify whether it was expected and correctly applied.",next_steps:["Verify the underlying transaction and account/card terms.","If unexpected, contact the issuer and request the charge basis or reversal eligibility."],evidence:{posted_date:t.posted_date,raw_description:t.raw_description,amount:t.amount,currency:t.currency}});
          }
        }

        if(["fraud_watch","high_value"].includes(rule.rule_type)){
          const th=Number(cfg.threshold_amount??0);
          if(th>0)for(const t of tx)if(t.direction==="debit"&&Number(t.amount)>=th)await add({watch_rule_id:rule.id,profile_id:t.profile_id,transaction_id:t.id,finding_type:"high_value_transaction",severity:rule.severity??"warning",title:"High-value debit: "+t.amount+" "+t.currency,explanation:"This debit met the configured threshold. It is an anomaly signal, not proof of fraud.",next_steps:["Confirm the merchant/recipient and amount.","If unrecognized, contact the financial institution promptly."],evidence:{threshold:th,posted_date:t.posted_date,merchant:t.merchant_normalized??t.raw_description,amount:t.amount,currency:t.currency}});
        }

        if(rule.rule_type==="duplicate_charge"){
          const groups=new Map<string,any[]>();
          for(const t of tx.filter((x:any)=>x.direction==="debit")){
            const k=[t.account_id,Number(t.amount).toFixed(2),t.currency,norm(t.merchant_normalized??t.raw_description)].join("|");
            groups.set(k,[...(groups.get(k)??[]),t]);
          }
          for(const rows of groups.values()){
            rows.sort((a,b)=>String(a.posted_date).localeCompare(String(b.posted_date)));
            for(let i=1;i<rows.length;i++){
              const gap=Math.abs(new Date(rows[i].posted_date).getTime()-new Date(rows[i-1].posted_date).getTime());
              if(gap<=172800000){
                const t=rows[i];
                await add({watch_rule_id:rule.id,profile_id:t.profile_id,transaction_id:t.id,finding_type:"possible_duplicate_charge",severity:rule.severity??"warning",title:"Possible duplicate charge: "+t.amount+" "+t.currency,explanation:"Two very similar debits occurred close together; they may still be legitimate separate purchases.",next_steps:["Compare both transactions and receipts/order history.","If one is unrecognized, contact the issuer/merchant promptly."],evidence:{transaction_ids:[rows[i-1].id,t.id],dates:[rows[i-1].posted_date,t.posted_date],amount:t.amount}});
              }
            }
          }
        }

        if(rule.rule_type==="card_due"){
          const windowDays=Math.max(0,Math.min(Number(cfg.window_days??7),60));
          for(const s of cc.data??[]){
            if(!s.due_date||s.payment_status==="paid")continue;
            const dd=dayDiff(s.due_date);
            if(dd<=windowDays&&dd>=-30)await add({watch_rule_id:rule.id,transaction_id:null,finding_type:dd<0?"card_payment_overdue":"card_payment_due",severity:dd<0?"critical":(rule.severity??"warning"),title:(dd<0?"Credit-card payment overdue":"Credit-card payment due")+" on "+s.due_date,explanation:"A stored credit-card statement is not marked paid.",next_steps:["Verify whether payment has already been made.","If unpaid, review the issuer statement and due amount before taking action."],evidence:{statement_id:s.id,account_id:s.account_id,due_date:s.due_date,total_due:s.total_due,minimum_due:s.minimum_due,currency:s.currency,payment_status:s.payment_status}});
          }
        }

        if(rule.rule_type==="card_utilization"){
          const threshold=Number(cfg.threshold_percent??30);
          for(const a of accounts.data??[]){
            if(a.account_type!=="credit_card"||a.current_balance===null||!a.credit_limit||Number(a.credit_limit)<=0)continue;
            const pct=Number(a.current_balance)/Number(a.credit_limit)*100;
            if(pct>=threshold)await add({watch_rule_id:rule.id,transaction_id:null,finding_type:"high_card_utilization",severity:rule.severity??"notice",title:"Credit-card utilization "+pct.toFixed(1)+"%",explanation:"The stored current balance exceeds the configured utilization threshold.",next_steps:["Verify the balance and credit limit are current.","Consider payment timing based on your own cash-flow priorities."],evidence:{account_id:a.id,balance:a.current_balance,credit_limit:a.credit_limit,utilization_percent:Number(pct.toFixed(2)),threshold_percent:threshold}});
          }
        }

        if(rule.rule_type==="insurance_renewal"){
          const windowDays=Math.max(0,Math.min(Number(cfg.window_days??30),180));
          for(const x of ins.data??[]){
            if(!x.renewal_date)continue;
            const dd=dayDiff(x.renewal_date);
            if(dd>=0&&dd<=windowDays)await add({watch_rule_id:rule.id,profile_id:x.profile_id,transaction_id:null,finding_type:"insurance_renewal_upcoming",severity:rule.severity??"notice",title:"Insurance renewal due "+x.renewal_date,explanation:"A stored insurance policy has an upcoming renewal date.",next_steps:["Review coverage, premium and renewal terms before the due date."],evidence:{policy_id:x.id,policy_name:x.policy_name,renewal_date:x.renewal_date,premium_amount:x.premium_amount,currency:x.currency}});
          }
        }

        if(rule.rule_type==="goal_watch"){
          const windowDays=Math.max(1,Math.min(Number(cfg.window_days??90),3650));
          for(const g of goals.data??[]){
            if(!g.target_date||g.target_amount===null)continue;
            const dd=dayDiff(g.target_date), current=Number(g.current_amount??0), target=Number(g.target_amount);
            if(dd<=windowDays&&current<target)await add({watch_rule_id:rule.id,profile_id:g.profile_id,transaction_id:null,finding_type:dd<0?"goal_overdue":"goal_behind_target",severity:rule.severity??"notice",title:(dd<0?"Goal target date passed: ":"Goal approaching: ")+g.name,explanation:"The stored goal has not yet reached its target amount.",next_steps:["Review the goal assumptions and contribution plan."],evidence:{goal_id:g.id,target_date:g.target_date,current_amount:current,target_amount:target,currency:g.currency,days_to_target:dd}});
          }
        }

        if(["budget_watch","spending_watch"].includes(rule.rule_type)){
          for(const b of budgets.data??[]){
            const from=b.start_date, to=b.end_date??now.toISOString().slice(0,10);
            const relevant=tx.filter((t:any)=>t.direction==="debit"&&t.currency===b.currency&&t.posted_date>=from&&t.posted_date<=to&&(!b.category||t.category===b.category)&&(!b.subcategory||t.subcategory===b.subcategory));
            const spent=relevant.reduce((s:number,t:any)=>s+Number(t.amount),0);
            if(spent>Number(b.amount))await add({watch_rule_id:rule.id,profile_id:b.profile_id,transaction_id:null,finding_type:"budget_exceeded",severity:rule.severity??"warning",title:"Budget exceeded: "+b.name,explanation:"Confirmed debits in the budget period exceed the stored budget amount.",next_steps:["Review the transactions included in this budget.","Adjust spending or the budget only if that reflects your actual plan."],evidence:{budget_id:b.id,budget_amount:b.amount,spent:Number(spent.toFixed(2)),currency:b.currency,category:b.category,from,to}});
          }
        }

        if(["recurring_watch","subscription_watch"].includes(rule.rule_type)){
          const windowDays=Math.max(0,Math.min(Number(cfg.window_days??7),90));
          for(const x of recurring.data??[]){
            if(!x.next_expected_date)continue;
            if(rule.rule_type==="subscription_watch"&&x.item_type!=="subscription")continue;
            const dd=dayDiff(x.next_expected_date);
            if(dd>=0&&dd<=windowDays)await add({watch_rule_id:rule.id,profile_id:x.profile_id,transaction_id:null,finding_type:"recurring_item_upcoming",severity:rule.severity??"info",title:"Upcoming recurring item: "+x.name,explanation:"A stored recurring item is expected soon.",next_steps:["Verify the amount/date if the plan has changed."],evidence:{recurring_item_id:x.id,item_type:x.item_type,next_expected_date:x.next_expected_date,amount:x.amount,currency:x.currency}});
          }
        }

        if(rule.rule_type==="investment_concentration"){
          const threshold=Number(cfg.threshold_percent??40);
          const byCurrency=new Map<string,any[]>();
          for(const x of investments.data??[])if(x.current_value!==null&&Number(x.current_value)>=0)byCurrency.set(x.currency,[...(byCurrency.get(x.currency)??[]),x]);
          for(const [currency,rows] of byCurrency.entries()){
            const total=rows.reduce((s,x)=>s+Number(x.current_value),0); if(total<=0)continue;
            for(const x of rows){const pct=Number(x.current_value)/total*100;if(pct>=threshold)await add({watch_rule_id:rule.id,profile_id:x.profile_id,transaction_id:null,finding_type:"investment_concentration",severity:rule.severity??"notice",title:"Investment concentration "+pct.toFixed(1)+"%: "+x.name,explanation:"One stored investment represents at least the configured share of tracked investments in the same currency. This is a concentration signal, not a buy/sell recommendation.",next_steps:["Review whether the concentration matches your intended allocation and risk tolerance."],evidence:{investment_id:x.id,current_value:x.current_value,currency,portfolio_value:total,concentration_percent:Number(pct.toFixed(2)),threshold_percent:threshold}});}
          }
        }

        if(rule.rule_type==="refund_watch"){
          const expectedBy=String(cfg.expected_by??"");
          const amount=Number(cfg.amount??0), currency=String(cfg.currency??"INR").toUpperCase(), merchant=norm(cfg.merchant??"");
          if(expectedBy&&dayDiff(expectedBy)<0&&amount>0){
            const found=tx.some((t:any)=>t.direction==="credit"&&t.currency===currency&&Math.abs(Number(t.amount)-amount)<0.01&&(!merchant||norm(t.merchant_normalized??t.raw_description).includes(merchant)));
            if(!found)await add({watch_rule_id:rule.id,transaction_id:null,finding_type:"refund_not_found",severity:rule.severity??"warning",title:"Expected refund not found",explanation:"No matching confirmed credit was found by the configured expected date.",next_steps:["Check the merchant/issuer refund status and whether the refund posted under a different description or amount."],evidence:{expected_by:expectedBy,amount,currency,merchant:cfg.merchant??null}});
          }
        }

        if(rule.rule_type==="cash_flow_watch"){
          const threshold=Number(cfg.minimum_net_cash_flow??0);
          const currency=String(cfg.currency??"INR").toUpperCase();
          const rows=tx.filter((t:any)=>t.currency===currency&&t.direction!=="transfer");
          const net=rows.reduce((s:number,t:any)=>s+(t.direction==="credit"?Number(t.amount):-Number(t.amount)),0);
          if(net<threshold)await add({watch_rule_id:rule.id,transaction_id:null,finding_type:"cash_flow_below_threshold",severity:rule.severity??"notice",title:"Net cash flow below configured threshold",explanation:"Confirmed inflows minus outflows in the lookback period are below the configured threshold.",next_steps:["Review the included period and transactions before changing spending or savings plans."],evidence:{lookback_days:days,net_cash_flow:Number(net.toFixed(2)),threshold,currency}});
        }
      }

      for(const f of fr.data??[]){
        if(!f.confirmed_through||!f.expected_frequency_days)continue;
        const age=Math.floor((Date.now()-new Date(f.confirmed_through+"T00:00:00Z").getTime())/86400000);
        if(age>Number(f.expected_frequency_days))await add({watch_rule_id:null,transaction_id:null,finding_type:"stale_data",severity:"notice",title:"Financial data may be stale: "+(f.accounts?.name??"account"),explanation:"Confirmed data is "+age+" days old, beyond the configured freshness interval.",next_steps:["Import newer account data before relying on complete-period analysis."],evidence:{account_id:f.account_id,confirmed_through:f.confirmed_through,age_days:age}});
      }

      let created=0;
      for(const f of findings){
        const r=await db.from("watch_findings").insert(f);
        if(!r.error)created++; else if(String(r.error.code)!=="23505")throw r.error;
      }
      await db.from("watch_rules").update({last_run_at:new Date().toISOString()}).eq("workspace_id",ws).eq("enabled",true);
      return respond({evaluated_transactions:tx.length,findings_generated:findings.length,new_findings_created:created,findings});
    }
    if(op==="list_watch_findings"){
      reqFields(p,["workspace_id"]);let q=db.from("watch_findings").select("*").eq("workspace_id",p.workspace_id).order("created_at",{ascending:false}).limit(Math.min(Number(p.limit??100),500));if(p.status)q=q.eq("status",p.status);if(p.severity)q=q.eq("severity",p.severity);const r=await q;if(r.error)throw r.error;return respond({findings:r.data??[]});
    }
    if(op==="request_workspace_erasure"){
      reqFields(p,["workspace_id","reason"]);
      const w=await db.from("workspaces").select("id,name,base_currency").eq("id",p.workspace_id).single(); if(w.error)throw w.error;
      const pending=await db.from("pending_operations").insert({workspace_id:p.workspace_id,operation_type:"permanent_delete_record",target_table:"workspaces",target_id:p.workspace_id,before_snapshot:w.data,reason:String(p.reason)}).select().single();
      if(pending.error)throw pending.error;
      return respond({pending_operation:pending.data,workspace:w.data,confirmation_required:true,warning:"Confirming permanently erases the workspace and all FinanceCanvas records linked to it. Export first if needed."});
    }
    if(op==="confirm_workspace_erasure"){
      reqFields(p,["workspace_id","operation_id","confirmed"]);
      const o=await db.from("pending_operations").select("*").eq("workspace_id",p.workspace_id).eq("id",p.operation_id).eq("target_table","workspaces").eq("operation_type","permanent_delete_record").single();
      if(o.error)throw o.error;
      if(o.data.status!=="pending")return respond({error:"Operation is "+o.data.status},409);
      if(p.confirmed!==true){await db.from("pending_operations").update({status:"cancelled"}).eq("id",o.data.id);return respond({cancelled:true});}
      if(new Date(o.data.expires_at).getTime()<Date.now()){return respond({error:"Pending operation expired"},409);}
      const d=await db.from("workspaces").delete().eq("id",p.workspace_id); if(d.error)throw d.error;
      return respond({erased:true,workspace_id:p.workspace_id});
    }
    if(op==="export_workspace_json"){
      reqFields(p,["workspace_id"]);const tables=["workspaces","profiles","institutions","accounts","imports","transactions","transaction_splits","merchant_aliases","loans","loan_payments","insurance_policies","assets","liabilities","investments","investment_transactions","subscriptions","goals","correction_memory","duplicate_reviews","audit_log","watch_rules","watch_findings","data_freshness","households","household_members","profile_relationships","asset_owners","liability_owners","loan_borrowers","account_balances","credit_card_statements","budgets","recurring_items","financial_snapshots","processing_consents","sensitive_data_events","privacy_requests","breach_incidents","extracted_fields","confirmation_queue"], out:Record<string,any>={};
      for(const table of tables){let q=db.from(table).select("*");q=table==="workspaces"?q.eq("id",p.workspace_id):q.eq("workspace_id",p.workspace_id);const r=await q;if(r.error)throw r.error;out[table]=r.data??[]}
      const owners=await db.from("account_owners").select("*,accounts!inner(workspace_id)").eq("accounts.workspace_id",p.workspace_id); if(owners.error) throw owners.error; out.account_owners=owners.data??[];
      return respond({schema_version:"0.1.0",exported_at:new Date().toISOString(),workspace_id:p.workspace_id,data:out});
    }
    if(op==="export_workspace_csv"){
      reqFields(p,["workspace_id"]);
      const tables=["profiles","institutions","accounts","imports","transactions","transaction_splits","merchant_aliases","loans","loan_payments","insurance_policies","assets","liabilities","investments","investment_transactions","subscriptions","goals","correction_memory","duplicate_reviews","audit_log","watch_rules","watch_findings","data_freshness","households","household_members","profile_relationships","asset_owners","liability_owners","loan_borrowers","account_balances","credit_card_statements","budgets","recurring_items","financial_snapshots","processing_consents","sensitive_data_events","privacy_requests","breach_incidents","extracted_fields","confirmation_queue"];
      const files:Record<string,string>={};
      const w=await db.from("workspaces").select("*").eq("id",p.workspace_id); if(w.error)throw w.error; files["workspaces.csv"]=rowsToCsv(w.data??[]);
      for(const table of tables){const r=await db.from(table).select("*").eq("workspace_id",p.workspace_id);if(r.error)throw r.error;files[table+".csv"]=rowsToCsv(r.data??[])}
      const owners=await db.from("account_owners").select("*,accounts!inner(workspace_id)").eq("accounts.workspace_id",p.workspace_id); if(owners.error)throw owners.error; files["account_owners.csv"]=rowsToCsv(owners.data??[]);
      return respond({schema_version:"0.1.0",exported_at:new Date().toISOString(),workspace_id:p.workspace_id,files});
    }
    return respond({error:"Unknown operation: "+op},404);
  } catch(e){
    const status=Number((e as any)?.status??400);
    return respond({error:(e as Error).message??String(e),code:(e as any)?.code??"REQUEST_REJECTED",field:(e as any)?.field??null},status>=400&&status<600?status:400);
  }
});