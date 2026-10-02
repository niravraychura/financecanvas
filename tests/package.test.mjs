import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readdirSync } from 'node:fs';

test('reinstall package includes complete migrations, API and correction guidance',()=>{
  const packed=JSON.parse(execFileSync('npm',['pack','--dry-run','--json'],{encoding:'utf8'}))[0];
  const files=new Set(packed.files.map(x=>x.path));
  assert.equal(packed.version,'0.1.5');
  for(const path of ['SKILL.md','references/UPGRADING.md','references/CONNECTOR_MODE.md','supabase/functions/financecanvas-api/index.ts','SECURITY_CHECKLIST.md']) assert.ok(files.has(path),path);
  for(const name of readdirSync('supabase/migrations').filter(x=>x.endsWith('.sql'))) assert.ok(files.has('supabase/migrations/'+name),name);
  assert.ok(![...files].some(x=>x==='node_modules'||x.startsWith('node_modules/')||x.endsWith('.pdf')||x==='.env'));
  execFileSync('python',['scripts/package_skill.py']);
  execFileSync('python',['-c',`import zipfile
from pathlib import Path
with zipfile.ZipFile('dist/financecanvas.zip') as z:
 names=set(z.namelist())
 for p in Path('supabase/migrations').glob('*.sql'):
  assert 'financecanvas/'+p.as_posix() in names
 assert 'financecanvas/SECURITY_CHECKLIST.md' in names
 assert 'financecanvas/references/UPGRADING.md' in names
 assert z.read('financecanvas/supabase/functions/financecanvas-api/index.ts')==Path('supabase/functions/financecanvas-api/index.ts').read_bytes()
`]);
});
