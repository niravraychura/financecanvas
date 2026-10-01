# FinanceCanvas

**FinanceCanvas is a portable AI Personal CFO skill with a structured, user-controlled Supabase data layer.**

[![CI](https://github.com/niravraychura/financecanvas/actions/workflows/ci.yml/badge.svg)](https://github.com/niravraychura/financecanvas/actions/workflows/ci.yml)

FinanceCanvas is designed for individuals, couples, and households that want an AI assistant to understand long-term financial history without turning uploaded statements, receipts, screenshots, or bills into a permanent document archive.

> **Status:** Personal/private v0.1 reference implementation.  
> **Commercial/public production:** intentionally marked `production_ready = false` until the production gate in [COMPLIANCE.md](COMPLIANCE.md) is completed.

## Why FinanceCanvas

A normal chat can analyze a statement you upload today, but it may not have a reliable structured record months later.

FinanceCanvas turns confirmed financial facts into a persistent financial model so you can ask questions such as:

- "What was my XYZ Bank balance on 15 March 2026?"
- "How much did we spend on travel last year?"
- "Did this subscription increase its price?"
- "Show every unexpected fee or forex markup."
- "Are any credit cards near their due dates or utilization limit?"
- "How has our net worth changed?"
- "Can I afford this home under these loan assumptions?"
- "Which transactions made this recommendation?"

When evidence is incomplete, FinanceCanvas is designed to say so rather than guess.

---

## Contents

- [Features](#features)
- [Architecture](#architecture)
- [Installation](#installation)
- [First-time setup](#first-time-setup)
- [Using FinanceCanvas](#using-financecanvas)
- [Historical balance example](#historical-balance-example)
- [FinanceCanvas Watch](#financecanvas-watch)
- [Privacy and security](#privacy-and-security)
- [Data model and evidence](#data-model-and-evidence)
- [Testing](#testing)
- [Updating](#updating)
- [Project documentation](#project-documentation)
- [Commercial/public deployment](#commercialpublic-deployment)

---

## Features

### Personal and household finance

- multiple financial profiles in one workspace;
- households and profile relationships;
- personal, business and shared transaction purposes;
- split transactions;
- account/asset/liability/loan ownership percentages and roles;
- multi-currency storage with an explicit workspace base currency.

### Accounts and transaction history

- bank accounts;
- credit cards;
- wallets/cash/brokerage/loan/other accounts;
- historical account balances;
- credit-card statements;
- transaction running balances;
- same-day statement sequence/order;
- merchant normalization and learned aliases;
- user-confirmed categories and corrections.

### Financial Inbox

Temporary inputs can include:

- PDF
- JPG/JPEG
- PNG/screenshots
- CSV
- XLS/XLSX
- pasted text

Import states:

```text
received
  -> detected
  -> extracted
  -> validated
  -> needs_review
  -> confirmed
  -> committed
  -> completed
```

Only uncertain/material items should be presented for review before the final import confirmation.

### Duplicate protection

FinanceCanvas protects against duplicates at multiple levels:

1. SHA-256 source-document hash when source bytes are available;
2. deterministic transaction fingerprint;
3. exact duplicate lookup;
4. near-duplicate comparison;
5. explicit override reason if the user intentionally keeps a duplicate.

Confirmed transaction batches are committed **atomically**: either the whole prepared batch succeeds or it rolls back.

### Financial records

First-class records exist for:

- income sources;
- loans and loan payments;
- insurance and premium history;
- assets and liabilities;
- investments and investment transactions;
- investment allocation targets;
- subscriptions and recurring items;
- budgets;
- financial goals;
- historical financial snapshots.

### Financial memory

FinanceCanvas can persist **user-confirmed** preferences such as:

- emergency-fund policy;
- budgeting conventions;
- savings priorities;
- shared-expense rules;
- payment/card-strategy preferences;
- risk-profile wording;
- goal assumptions.

Blocked secrets and identity credentials are never valid "financial preferences."

### Recommendation history

Material recommendations can retain:

- rationale;
- evidence;
- assumptions;
- confidence;
- accepted/rejected/dismissed/completed status.

Recommendations remain interpretations, not database facts.

### Historical questions and evidence

FinanceCanvas supports:

- historical balance queries;
- evidence bundles;
- financial timeline;
- ownership graph;
- data-freshness information;
- exact vs reconstructed vs estimated answer labels.

### Scenario analysis

Deterministic what-if analysis can cover:

- home/down-payment scenarios;
- loan EMI/tenure/rate scenarios;
- prepayment scenarios;
- emergency-fund changes;
- savings goals;
- rent-vs-EMI cash flow;
- user-directed income/expense changes.

Scenario values remain separate from confirmed records.

---

## Architecture

```text
                Owner / Developer
                       |
             Authorized Supabase connector
              (maintenance / deployment)
                       |
                       v
+------------------------------------------------+
|                 Supabase project               |
|                                                |
|  Edge Function: financecanvas-api              |
|             |                                  |
|             v                                  |
|  PostgreSQL structured financial data          |
|  + RLS enabled                                 |
|  + direct anon/authenticated DML revoked       |
+------------------------------------------------+
                       ^
                       |
          restricted approved operations
                       |
               FinanceCanvas Skill
                       ^
                       |
          ChatGPT / compatible AI / client
```

### Important trust boundary

An owner/developer Supabase admin connector is useful for installation and maintenance, but it can execute privileged database operations.

**Normal runtime access should use the restricted FinanceCanvas API or an equivalently least-privilege connector.**

Editing `SKILL.md` must not silently remove database/API enforcement for:

- duplicate protection;
- atomic imports;
- sensitive-data rejection;
- two-step edits/deletes;
- workspace erasure;
- cross-workspace protection;
- audit history.

---

# Installation

For the complete setup guide, read **[INSTALL.md](INSTALL.md)**.

For the shortest setup path, read **[QUICKSTART.md](QUICKSTART.md)**.

## Prerequisites

- Git
- a Supabase project
- an AI/agent environment that can load repository/project instructions or a Skill file
- Python 3.11+ recommended for tests/helper scripts
- Supabase CLI optional if you prefer terminal deployment

## 1. Clone the repository

```bash
git clone https://github.com/niravraychura/financecanvas.git
cd financecanvas
```

## 2. Run the safety checks

```bash
python -m unittest discover -s tests -v
python scripts/security_check.py
```

Do not continue if either command fails.

## 3. Install/load the Skill

Do **not** copy only `SKILL.md`.

Keep the Skill and references together:

```text
financecanvas/
├── SKILL.md
├── references/
├── SECURITY.md
├── SECURITY_CHECKLIST.md
└── AGENTS.md
```

If your AI host supports repository/project instructions, add the repository to that project and instruct it to use `SKILL.md`.

If your host supports a Skills directory, copy or link the **whole FinanceCanvas directory** into that host's supported Skills location so the relative `references/` files remain available.

The exact Skills-directory path is host-specific; use the current documentation for your AI host.

## 4. Deploy Supabase

### Connector-first owner setup

If your AI host already has an explicitly authorized Supabase connector:

- use it for owner/developer maintenance;
- apply every migration under `supabase/migrations/` in filename order;
- do **not** create a local Supabase-admin `.env` merely to duplicate existing connector credentials;
- never paste the connector's credentials into chat or GitHub.

### Supabase CLI setup

```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
supabase functions deploy financecanvas-api --no-verify-jwt
```

`--no-verify-jwt` is intentional because `financecanvas-api` implements its own FinanceCanvas runtime-key authentication.

Do not put a Supabase server/service-role secret into the Skill or client.

## 5. External-client runtime access

You do **not** need this when you are only doing owner maintenance through an authorized Supabase connector.

For an external LLM/app that needs the restricted API, generate a runtime key locally:

```bash
python scripts/generate_api_key.py --workspace-id YOUR_WORKSPACE_UUID
```

Store the plaintext `fc_...` value in the client's secret store.

Only its SHA-256 hash belongs in Supabase.

Recommended normal scopes:

```text
read,write,watch,export
```

Do not grant `admin` to an ordinary runtime client.

See [INSTALL.md](INSTALL.md) for the full bootstrap procedure.

## 6. Run acceptance testing

Before real financial data:

```bash
FINANCECANVAS_API_URL="https://YOUR_PROJECT_REF.supabase.co/functions/v1/financecanvas-api" \
FINANCECANVAS_BOOTSTRAP_API_KEY="fc_..." \
python scripts/acceptance_test.py
```

The test uses synthetic data only and cleans up its test workspace.

See [ACCEPTANCE_TEST.md](ACCEPTANCE_TEST.md).

---

## First-time setup

On first persistent use FinanceCanvas checks whether a workspace exists.

It should ask:

> Would you like to set up your FinanceCanvas workspace now?

If yes, provide:

- workspace name;
- base currency;
- first financial profile name.

If you decline, FinanceCanvas can use an internal default personal workspace that may be renamed later.

No real workspace is automatically created merely by cloning/installing the repository.

---

## Using FinanceCanvas

### Import a statement

```text
Import this March bank statement into FinanceCanvas.

First warn me if it contains sensitive information.
Do not store the source document.
Show me only uncertain/conflicting items.
Do not commit anything until I confirm.
```

### Ask a historical question

```text
What was my XYZ Bank balance on 15 March 2026?

Tell me whether the answer is exact, reconstructed, or insufficient,
and show the evidence coverage.
```

### Inspect spending

```text
Show my confirmed dining spend from January through March.
Tell me which accounts and transactions are included.
```

### Run Watch

```text
Run FinanceCanvas Watch and show anything unusual:
duplicate charges, unexpected fees, subscription changes,
high utilization, due dates, EMI changes, refunds,
reconciliation problems, spending anomalies, and stale data.
```

### Run a scenario

```text
Using my confirmed FinanceCanvas baseline, compare a 20-year and
25-year home-loan scenario. Keep all scenario assumptions separate
from real financial records.
```

---

## Historical balance example

If a March 2026 statement contains running balances:

```text
Date          Transaction                 Balance after
15-Mar-2026   Synthetic Rent              ₹1,200
15-Mar-2026   Synthetic Cafe              ₹1,150
```

FinanceCanvas stores both the running balance and statement sequence.

A later query for the end-of-day balance on 15 March can return:

```text
Balance: ₹1,150
Method: exact statement running balance
Confidence: exact_from_confirmed_running_balance
Evidence: statement import + final transaction sequence for 15 March
```

If no running balance exists, FinanceCanvas may reconstruct from a confirmed balance anchor plus all confirmed intervening transactions.

If coverage/order cannot be proved, it must return **insufficient/ambiguous data**, not guess.

---

## FinanceCanvas Watch

Implemented Watch categories include:

- potential fraud / configured high-value debits;
- unexpected fees, finance charges, forex markups and surcharges;
- possible duplicate charges;
- subscription amount changes;
- cancelled-subscription reappearance;
- card payment due/overdue;
- card utilization;
- annual fee / waiver-progress context;
- insurance renewal;
- financial goal progress;
- budget/spending threshold;
- recurring item/subscription reminders;
- investment concentration;
- investment allocation drift;
- expected refund not found;
- cash-flow threshold;
- loan/EMI changes;
- statement reconciliation failure;
- category spending anomaly;
- stale/missing financial data.

A Watch finding is a **signal**, not proof of fraud or wrongdoing.

### Scheduling

A stored Watch rule does not create background execution by itself.

If the host provides an automation/scheduler, use that system for the requested cadence.

Do not claim continuous or real-time monitoring unless a live data source and scheduler are actually connected.

---

## Privacy and security

### Source documents

FinanceCanvas does **not** intentionally persist uploaded PDFs/images/spreadsheets.

The host chat/LLM platform may independently retain uploads under its own privacy/retention settings. FinanceCanvas must not claim it can delete the host's copy unless the host exposes that capability.

### Critical secrets — never persist

Examples:

- CVV/CVC
- OTP
- ATM/card/UPI PIN
- passwords/passcodes
- recovery/seed phrases
- private keys
- API/access/refresh tokens
- bank login credentials

If detected, FinanceCanvas should warn the user, avoid repeating the value, block persistence, and give appropriate remediation steps.

### High-risk identifiers

v0.1 minimizes/blocks full:

- card numbers;
- bank-account numbers;
- Aadhaar/VID;
- PAN;
- passport/tax identifiers.

Accounts/cards normally use masked values or last four digits.

### Repository safety

The public repository must never contain:

- production credentials;
- real statements/receipts/screenshots;
- real financial exports;
- database dumps;
- real personal account/card/government-ID data.

Every change requires the review in [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md).

CI runs:

```bash
python -m unittest discover -s tests -v
python scripts/security_check.py
```

---

## Data model and evidence

Core model groups include:

- identity/workspaces/profiles/households;
- institutions/accounts/account ownership;
- transactions/imports/Financial Inbox;
- loans/liabilities/insurance;
- assets/investments;
- income/budgets/goals/subscriptions/recurring items;
- financial preferences/recommendations;
- Watch rules/findings;
- privacy/security/audit records.

See [references/DATA_MODEL.md](references/DATA_MODEL.md).

For evidence-aware answers see [references/HISTORY_AND_EVIDENCE.md](references/HISTORY_AND_EVIDENCE.md).

---

## Testing

### Local tests

```bash
python -m unittest discover -s tests -v
python scripts/security_check.py
```

### Acceptance test

See [ACCEPTANCE_TEST.md](ACCEPTANCE_TEST.md).

The reference implementation has been validated using synthetic March-2026 data, including:

- 5-row atomic import;
- duplicate-batch rollback;
- source-document hash duplicate blocking;
- exact historical 15-March running balance;
- evidence/timeline/ownership queries;
- JSON/CSV export;
- Watch execution;
- preference/recommendation persistence;
- two-step edit;
- complete synthetic-data cleanup.

The live API was also exercised over HTTP from inside Supabase.

No synthetic acceptance workspace or test runtime key is retained after cleanup.

---

## Updating

Before applying an update:

1. review [CHANGELOG.md](CHANGELOG.md);
2. review new migrations;
3. pull the repository;
4. run tests/security checks;
5. apply migrations;
6. redeploy the Edge Function if its source changed;
7. complete [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md).

```bash
git pull
python -m unittest discover -s tests -v
python scripts/security_check.py
```

Never treat a **BLOCKED** security review as a completed release.

---

## Project documentation

| Document | Purpose |
|---|---|
| [INSTALL.md](INSTALL.md) | Full installation guide |
| [QUICKSTART.md](QUICKSTART.md) | Minimal setup path |
| [SKILL.md](SKILL.md) | Portable FinanceCanvas behavior |
| [ACCEPTANCE_TEST.md](ACCEPTANCE_TEST.md) | Acceptance-test process/results |
| [SECURITY.md](SECURITY.md) | Security policy |
| [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) | Mandatory post-change security review |
| [THREAT_MODEL.md](THREAT_MODEL.md) | Trust boundaries and threats |
| [DATA_RETENTION.md](DATA_RETENTION.md) | Retention/deletion rules |
| [INCIDENT_RESPONSE.md](INCIDENT_RESPONSE.md) | Incident-response runbook |
| [COMPLIANCE.md](COMPLIANCE.md) | Legal/regulatory engineering baseline |
| [PRIVACY.md](PRIVACY.md) | Privacy-notice template |
| [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) | Release gate |
| [ROADMAP.md](ROADMAP.md) | Deferred production work |
| [AGENTS.md](AGENTS.md) | Mandatory instructions for coding/AI agents |
| [references/](references/) | Calculation/import/Watch/data/evidence/scenario rules |

---

## Commercial/public deployment

Personal/private v0.1 is deliberately different from a public financial service.

Before setting `production_ready=true`, complete the applicable production gate, including items such as:

- production identity/tenant authentication;
- end-to-end authorization design;
- privacy notice/terms and operator identity;
- processor/subprocessor review;
- incident notification process;
- backup/DR testing;
- penetration/authorization testing;
- regulated review for bank aggregation/payment/investment-advice features.

See [COMPLIANCE.md](COMPLIANCE.md) and [ROADMAP.md](ROADMAP.md).

---

## License

No open-source license has been selected yet.

A public GitHub repository does **not** by itself grant permission to copy, modify, distribute, or commercially use the code.
