import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import ts from 'typescript';

const src=readFileSync('supabase/functions/financecanvas-api/index.ts','utf8');
// Compile the shipped source, disabling only runtime startup and the external import.
const js=ts.transpileModule(src.replace(/^import .*\n/,''),{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.None},reportDiagnostics:true});
assert.equal(js.diagnostics?.filter(d=>d.category===ts.DiagnosticCategory.Error).length??0,0);
const sandbox={Deno:{serve(){}},console,Response,crypto:globalThis.crypto};
vm.createContext(sandbox);
vm.runInContext(js.outputText+'\nglobalThis.helpers={sanitizeValue,applyStoredMerchantAliases,autoEnrichTransaction,validateStatementNarrations,requiredScope};',sandbox);
const h=sandbox.helpers;

test('sanitization preserves analysis while blocking payment secrets',()=>{
  assert.equal(h.sanitizeValue({raw_description:'Synthetic merchant'}).raw_description,'Synthetic merchant');
  assert.throws(()=>h.sanitizeValue({raw_description:'password: synthetic-value'}),/secret detected/);
  assert.throws(()=>h.sanitizeValue({account_number:'123456789'}),/not allowed/);
  assert.match(h.sanitizeValue('4111 1111 1111 1111'),/LAST4_1111/);
});
test('saved aliases precede generic rules and preserve explicit categories',()=>{
  const a=[{raw_pattern:'Synthetic Merchant',normalized_merchant:'Synthetic Store',category:'Shopping'}];
  const result=h.autoEnrichTransaction(h.applyStoredMerchantAliases({raw_description:'Synthetic Merchant'},a));
  assert.equal(result.merchant_normalized,'Synthetic Store');
  assert.equal(result.category,'Shopping');
  assert.equal(h.applyStoredMerchantAliases({raw_description:'Synthetic Merchant',category:'User category'},a).category,'User category');
  const person=h.applyStoredMerchantAliases({raw_description:'Synthetic Person'},[{raw_pattern:'Synthetic Person',normalized_merchant:'Synthetic full name'}]);
  assert.equal(person.category,undefined);
});
test('every transaction-source format requires retained narration',async()=>{
  for(const type of ['bank_statement','credit_card_statement','transaction_history','csv','xlsx','pasted_text']){
    const db={from(){return {select(){return this},eq(){return this},in(){return this},is(){return Promise.resolve({data:[{id:'synthetic-import',source_type:type,detected_document_type:type}]})}}}};
    await assert.rejects(h.validateStatementNarrations(db,'synthetic-workspace',[{import_id:'synthetic-import'}]),/must retain sanitized/);
    await h.validateStatementNarrations(db,'synthetic-workspace',[{import_id:'synthetic-import',raw_description:'Synthetic Merchant'}]);
  }
});
test('correction and entity commits require write scope',()=>{
  for(const op of ['commit_entity_import','commit_transaction_repair','commit_transaction_clarifications','enrich_transactions']) assert.equal(h.requiredScope(op),'write');
  assert.equal(h.requiredScope('preview_transaction_clarifications'),'read');
});
