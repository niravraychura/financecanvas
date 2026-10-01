# Installing FinanceCanvas

FinanceCanvas has two parts:

1. the **portable AI Skill** — `SKILL.md` plus the files under `references/`;
2. the **optional persistent data layer** — Supabase migrations + the restricted `financecanvas-api` Edge Function.

For personal use, the recommended setup is **Supabase Free + connector-first owner maintenance + restricted runtime access**.

> Do not paste Supabase server/admin credentials into chat. Do not commit secrets to GitHub.

## Prerequisites

Required:

- Git
- a Supabase project
- an AI/agent environment that can load repository/project instructions or a Skill file

Optional:

- Supabase CLI, if you want to deploy from your own terminal
- Python 3.11+ for helper/test scripts

## 1. Clone FinanceCanvas

```bash
git clone https://github.com/niravraychura/financecanvas.git
cd financecanvas
```

Run the local safety checks:

```bash
python -m unittest discover -s tests -v
python scripts/security_check.py
```

Both must pass before you continue.

## 2. Install/load the Skill

Keep the following together:

```text
financecanvas/
├── SKILL.md
├── references/
├── SECURITY.md
├── SECURITY_CHECKLIST.md
└── AGENTS.md
```

### AI hosts that support repository/project instructions

Add the repository to the AI project/workspace and instruct the host to use `SKILL.md` as the FinanceCanvas skill/instructions.

The AI must be able to read the `references/` directory because `SKILL.md` delegates calculation, import, Watch, evidence, memory, scenario and compliance behavior to those files.

### AI hosts that support a Skills directory

Copy or link the **whole FinanceCanvas directory**, not only `SKILL.md`, into the host's supported Skills directory. Preserve the repository layout so relative references continue to work.

The exact Skills-directory path is host-specific and can change; follow your host's current documentation.

### ChatGPT with an authorized Supabase connector

For owner/developer maintenance, connect Supabase through the host's authorized connector/plugin and authorize the FinanceCanvas project.

In this mode:

- you do **not** need to create a local `.env` just to duplicate Supabase admin credentials;
- never copy connector credentials into chat or GitHub;
- use the connector for owner/developer deployment and maintenance;
- normal runtime access should still prefer the restricted FinanceCanvas API or an equivalently least-privilege connector.

## 3. Deploy the Supabase database

### Option A — authorized Supabase connector

Use the authorized owner/developer connector to apply every SQL migration under:

```text
supabase/migrations/
```

in filename order.

Then verify:

- all expected migrations are applied;
- RLS is enabled;
- direct `anon`/`authenticated` DML remains revoked;
- `financecanvas_compliance_settings.production_ready` remains `false` for personal/prototype v0.1.

### Option B — Supabase CLI

Authenticate with Supabase using its normal CLI login flow. Keep any CLI token outside the repository.

Link your project:

```bash
supabase link --project-ref YOUR_PROJECT_REF
```

Apply migrations:

```bash
supabase db push
```

Do not use `db reset` against a project containing real FinanceCanvas data unless you intentionally want to destroy it.

## 4. Deploy the Edge Function

The Edge Function is the recommended restricted runtime adapter for external LLMs/apps.

With Supabase CLI:

```bash
supabase functions deploy financecanvas-api --no-verify-jwt
```

`--no-verify-jwt` is intentional here because the function implements FinanceCanvas API-key authentication itself.

Supabase supplies the server-side project environment to the function. Do not put a Supabase server key into `SKILL.md`, `.env.example`, GitHub, or a client prompt.

Verify the function reports **ACTIVE**.

## 5. Choose your access mode

### Mode 1 — connector-first owner/personal maintenance

If your AI host already has an explicitly authorized Supabase connector and you are the owner/developer, no local FinanceCanvas secret is required for maintenance.

This is convenient, but remember that an admin connector can bypass application safeguards. Normal financial operations should follow the Skill rules and, where practical, use the restricted API.

### Mode 2 — restricted external runtime

Use this for another LLM, application, automation host or client that does not have the trusted owner connector.

Generate a key locally:

```bash
python scripts/generate_api_key.py --workspace-id YOUR_WORKSPACE_UUID
```

The script prints:

- a one-time plaintext `fc_...` key for the client secret store;
- its SHA-256 hash;
- an SQL statement containing **only the hash**.

Execute the generated SQL using the owner Supabase connector/SQL editor.

Store the plaintext key only in the external host's secret store, for example:

```text
FINANCECANVAS_API_URL=https://YOUR_PROJECT_REF.supabase.co/functions/v1/financecanvas-api
FINANCECANVAS_API_KEY=fc_...
```

Do not commit that file/value.

Recommended runtime scopes:

```text
read,write,watch,export
```

Do not grant `admin` to a normal runtime client.

## 6. First initialization

On first persistent use, FinanceCanvas should call `initialization_status`.

If no workspace exists, it asks whether you want to configure one.

If yes, provide:

- workspace name;
- base currency, for example `INR`;
- first financial profile name.

If you decline, FinanceCanvas may create its internal default personal workspace, which can be renamed later.

## 7. Run the acceptance test

Before importing real financial data, run:

```bash
FINANCECANVAS_API_URL="https://YOUR_PROJECT_REF.supabase.co/functions/v1/financecanvas-api" \
FINANCECANVAS_BOOTSTRAP_API_KEY="fc_..." \
python scripts/acceptance_test.py
```

The bootstrap key must have `admin` access and should be temporary.

The acceptance script:

- creates a synthetic workspace;
- creates a synthetic profile/account/import;
- previews and atomically commits fake March transactions;
- verifies the 15 March historical balance;
- verifies exact-duplicate detection;
- exercises Watch, evidence, timeline, ownership and export operations;
- tests two-step edit;
- erases the synthetic workspace at the end.

No real financial data is used.

After the test, revoke/delete the bootstrap key unless you deliberately need it for installation administration.

See [ACCEPTANCE_TEST.md](ACCEPTANCE_TEST.md).

## 8. Run the security review

After installation and after **every future change**:

```bash
python -m unittest discover -s tests -v
python scripts/security_check.py
```

For database/API/auth/Skill changes, also complete [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md), including Supabase advisors and privilege checks.

## 9. Start using FinanceCanvas

Example prompts:

```text
Initialize FinanceCanvas for my personal finances.
```

```text
Import this bank statement into FinanceCanvas. Warn me about sensitive data first,
show uncertain items, and do not commit anything until I confirm.
```

```text
What was my XYZ Bank balance on 15 March 2026?
Show whether the answer is exact or reconstructed and show the evidence coverage.
```

```text
Check FinanceCanvas for duplicate charges, unexpected fees, subscription changes,
high card utilization and any other configured Watch findings.
```

## Updating FinanceCanvas

Pull changes:

```bash
git pull
```

Read the changelog and migrations before applying them.

Then run:

```bash
python -m unittest discover -s tests -v
python scripts/security_check.py
```

Apply new migrations and redeploy the Edge Function only after reviewing the security impact.

## Uninstalling

Removing the Skill files from your AI host does **not** delete FinanceCanvas data.

To remove FinanceCanvas data:

1. export your data if required;
2. use the two-step workspace-erasure flow;
3. confirm that you understand the impact;
4. revoke any remaining FinanceCanvas runtime keys.

Do not assume this removes independent copies held by the chat/LLM host, Supabase platform backups/logs, banks or other third parties.
