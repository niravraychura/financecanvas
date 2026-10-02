import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';

test('fresh install, database-only analysis, safe permanent corrections and rollback', async () => {
  const db = new PGlite({ extensions: { pg_trgm } });
  try {
    // Supabase-provided roles/auth/platform helper. PGlite lacks pgcrypto;
    // digest uses PostgreSQL's built-in SHA-256 for the tested fingerprint path.
    await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
      create schema auth; create table auth.users(id uuid primary key);
      create schema extensions;
      create function public.rls_auto_enable() returns event_trigger language plpgsql as $$begin end;$$;
      create function extensions.digest(text,text) returns bytea language sql immutable
        as $$select sha256(convert_to($1,'UTF8'))$$;`);
    const migrations = readdirSync('supabase/migrations').filter(x=>x.endsWith('.sql')).sort();
    for (const file of migrations) {
      const sql = readFileSync('supabase/migrations/'+file,'utf8')
        .replace('create extension if not exists pgcrypto;', '');
      assert.ok(sql.trim().length>0, 'empty migration: '+file);
      try { await db.exec(sql); } catch (e) { throw new Error(file+': '+e.message); }
    }
    assert.equal((await db.query('select schema_version from financecanvas_schema')).rows[0].schema_version,'0.1.5');
    for(const name of ['financecanvas_repair_transaction_analysis_by_reference_batch(uuid,uuid,jsonb)','financecanvas_repair_transaction_direction_batch(uuid,uuid,jsonb)'])
      assert.ok((await db.query('select to_regprocedure($1)::text name',[name])).rows[0].name);
    const query = async (sql,params=[]) => (await db.query(sql,params)).rows[0];
    const ws=(await query("insert into workspaces(name) values('Synthetic workspace') returning id")).id;
    const other=(await query("insert into workspaces(name) values('Synthetic other workspace') returning id")).id;
    const profile=(await query("insert into profiles(workspace_id,display_name) values($1,'Synthetic Person') returning id",[ws])).id;
    const account=(await query("insert into accounts(workspace_id,name,account_type) values($1,'Synthetic bank','bank') returning id",[ws])).id;
    const imp=(await query("insert into imports(workspace_id,account_id,source_type,detected_document_type) values($1,$2,'csv','transaction_export') returning id",[ws,account])).id;
    const row={workspace_id:ws,profile_id:profile,account_id:account,import_id:imp,posted_date:'2026-09-15',amount:25,currency:'INR',direction:'debit',base_fingerprint:'synthetic-fingerprint',fingerprint:'synthetic-fingerprint'};
    const commit=rows=>db.query('select financecanvas_commit_transaction_batch($1,$2::jsonb)',[ws,JSON.stringify(rows)]);
    await assert.rejects(commit([row]),/ANALYSIS_DATA_INCOMPLETE/);
    assert.equal((await query('select count(*)::int n from transactions')).n,0);
    row.raw_description='Synthetic Merchant';
    await commit([row]);
    const tx=await query('select id,updated_at from transactions');
    assert.equal((await query('select analysis_ready from imports where id=$1',[imp])).analysis_ready,true);
    await assert.rejects(commit([row]),/duplicate key/);
    assert.equal((await query('select count(*)::int n from transactions')).n,1);

    const rows=[{transaction_id:tx.id,context_note:'Synthetic travel accessories purchase',merchant_normalized:'Synthetic Store',category:'Shopping',subcategory:'Travel Accessories',scope:'transaction'}];
    const aliases=[{raw_pattern:'Synthetic Merchant',normalized_merchant:'Synthetic Store',category:'Shopping'}];
    const memories=[{correction_type:'merchant',source_value:'Synthetic Merchant',normalized_value:'Synthetic Store',extra:{context:'Synthetic reusable merchant'}}];
    const preview=await query('select financecanvas_private.preview_transaction_clarifications($1,$2::jsonb,$3::jsonb,$4::jsonb) result',[ws,JSON.stringify(rows),JSON.stringify(aliases),JSON.stringify(memories)]);
    assert.equal(preview.result.final_confirmation_required,true);
    rows[0].expected_updated_at=preview.result.results[0].expected_updated_at;
    const clarify=(workspace,rs,as=aliases,ms=memories,confirmed=true)=>db.query('select financecanvas_private.commit_transaction_clarifications($1,$2::jsonb,$3::jsonb,$4::jsonb,$5)',[workspace,JSON.stringify(rs),JSON.stringify(as),JSON.stringify(ms),confirmed]);
    await assert.rejects(clarify(ws,rows,aliases,memories,false),/FINAL_CONFIRMATION_REQUIRED/);
    await assert.rejects(clarify(other,rows),/CROSS_WORKSPACE_REFERENCE/);
    await assert.rejects(clarify(ws,[{...rows[0],context_note:'password: synthetic-test-value'}]),/CRITICAL_SECRET_DETECTED/);
    await assert.rejects(clarify(ws,rows,[{raw_pattern:'Incomplete alias'}]),/raw_pattern and normalized_merchant/);
    assert.equal((await query('select count(*)::int n from transaction_clarifications')).n,0);
    assert.equal((await query('select category from transactions')).category,null);
    await clarify(ws,rows);
    assert.equal((await query('select category from transactions')).category,'Shopping');
    for(const table of ['transaction_clarifications','merchant_aliases','correction_memory'])
      assert.equal((await query('select count(*)::int n from '+table)).n,1);
    assert.equal((await query("select count(*)::int n from audit_log where action='user_transaction_clarification'")).n,1);
    const stale=[{...rows[0],expected_updated_at:'2000-01-01T00:00:00Z'}];
    await assert.rejects(clarify(ws,stale),/STALE_PREVIEW/);
    const resolved=await query('select financecanvas_private.apply_transaction_aliases($1,$2::jsonb) result',[ws,JSON.stringify([{raw_description:'Synthetic Merchant'}])]);
    assert.equal(resolved.result[0].merchant_normalized,'Synthetic Store');
    assert.equal(resolved.result[0].category,'Shopping');
    const preserved=await query('select financecanvas_private.apply_transaction_aliases($1,$2::jsonb) result',[ws,JSON.stringify([{raw_description:'Synthetic Merchant',category:'User chosen category'}])]);
    assert.equal(preserved.result[0].category,'User chosen category');
    const isolated=await query('select financecanvas_private.apply_transaction_aliases($1,$2::jsonb) result',[other,JSON.stringify([{raw_description:'Synthetic Merchant'}])]);
    assert.equal(isolated.result[0].category,undefined);
    const grants=await query("select count(*)::int n from information_schema.role_table_grants where table_schema='public' and grantee in ('anon','authenticated')");
    assert.equal(grants.n,0);
    assert.equal((await query("select count(*)::int n from pg_tables where schemaname='public' and not rowsecurity")).n,0);
    for(const role of ['anon','authenticated']){
      assert.equal((await query("select has_function_privilege($1,'financecanvas_private.commit_transaction_clarifications(uuid,jsonb,jsonb,jsonb,boolean)','EXECUTE') ok",[role])).ok,false);
    }
    console.log('Applied '+migrations.length+' migrations to isolated PostgreSQL; no live data used.');
  } finally { await db.close(); }
});
