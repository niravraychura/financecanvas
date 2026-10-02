# FinanceCanvas

**FinanceCanvas is a portable AI Personal CFO skill with a structured, user-controlled Supabase data layer.**

[![CI](https://github.com/niravraychura/financecanvas/actions/workflows/ci.yml/badge.svg)](https://github.com/niravraychura/financecanvas/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent%20Skills-compatible-5c6ac4)](https://agentskills.io/)

FinanceCanvas is an open-source **personal finance AI agent skill / personal CFO** for ChatGPT, Codex, Claude Code, Cursor and other Agent-Skills-compatible assistants. It helps individuals, couples and households analyze bank and credit-card statements, track historical balances, cash flow, budgets, loans, insurance, investments and subscriptions, and detect duplicate charges, fees and financial anomalies without turning uploaded statements into a permanent document archive.

> **Status:** Personal/private v0.1 reference implementation.  
> **Commercial/public production:** intentionally marked `production_ready = false` until the production gate in [COMPLIANCE.md](COMPLIANCE.md) is completed.

## Supported AI environments

FinanceCanvas follows the open Agent Skills format and is intended to be portable across compatible hosts, including:

- ChatGPT Skills (upload/install through ChatGPT's Skills UI)
- OpenAI Codex
- Claude Code
- Cursor
- other Agent-Skills-compatible agents supported by the `skills` CLI

The persistent data layer is optional and **bring-your-own-Supabase**: each user can connect/select their own Supabase project. FinanceCanvas does not require users to share the author's database.

---

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

### Supported document imports

Connector-native persistent imports now cover:

- bank and credit-card statements;
- wallet/brokerage transaction statements;
- CSV/XLS/XLSX transaction exports;
- insurance policies and premium history;
- loan sanction/loan statements and repayments;
- investment portfolio/holding statements and investment events;
- salary/pay slips with dated income-payment history;
- asset and liability documents;
- subscription/recurring records;
- tax summaries/returns with identifiers minimized;
- goal-related structured data.

For changed existing loans, policies, holdings, income sources, assets, liabilities, subscriptions, goals, recurring items or tax summaries, FinanceCanvas shows the field differences and requires an explicit **Keep / Update / Add separate** decision. It never silently overwrites the existing record.

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

- income sources and dated income payments;
- loans and loan payments;
- insurance and premium history;
- assets and liabilities;
- investments and investment transactions;
- investment allocation targets;
- subscriptions and recurring items;
- budgets;
- financial goals;
- minimized tax records;
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

FinanceCanvas is **not a centrally hosted finance database**. Each user can bring their own Supabase project:

```text
User A + FinanceCanvas → User A's Supabase project
User B + FinanceCanvas → User B's Supabase project
User C + FinanceCanvas → User C's Supabase project
```

With an authorized Supabase connector:

```text
AI host / FinanceCanvas Skill
            |
            | user's authorized Supabase connector
            v
+------------------------------------------------+
|         User-selected Supabase project         |
|                                                |
|  financecanvas_private connector helpers       |
|  PostgreSQL structured FinanceCanvas data      |
|  + RLS enabled                                 |
|  + direct anon/authenticated DML revoked       |
|                                                |
|  Optional: financecanvas-api Edge Function     |
|  for external/non-connector runtimes           |
+------------------------------------------------+
```

No Supabase project reference, URL, organization ID, service key, or author-owned project is hardcoded into the Skill.

### Important trust boundary

An authorized Supabase owner connector can be used as the personal/private FinanceCanvas data path when it follows [references/CONNECTOR_MODE.md](references/CONNECTOR_MODE.md). The restricted Edge Function remains available for external clients that do not have an authorized connector.

A Supabase admin connector is powerful, so normal connector-mode operations are limited to the approved FinanceCanvas tables/functions and confirmation rules. It must never touch unrelated application data merely because the connector has access.

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

## Installation

### One command

Install FinanceCanvas globally into every supported local AI agent detected on your machine:

```bash
npx --yes github:niravraychura/financecanvas
```

Then open Claude Code, Cursor, Codex, or another Agent-Skills-compatible agent and say:

```text
Initialize FinanceCanvas.
```

That's the normal installation path. No repository clone is required just to install the Skill.

FinanceCanvas ships its own cross-platform installer so the primary one-liner does not depend on third-party global-link behavior. It installs to the universal Agent Skills directory plus the standard global skill locations for Claude Code, Cursor, Codex and Gemini CLI.

Standards-compatible alternative:

```bash
npx skills add niravraychura/financecanvas --all -g -y
```

### ChatGPT web

ChatGPT currently installs uploaded Skills through its Skills UI rather than a local shell command.

Build the upload bundle:

```bash
python scripts/package_skill.py
```

Then upload `dist/financecanvas.zip` from:

```text
Plugins → Skills → Create → Upload
```

For uncommon self-hosted/backend/developer setup, see [ADVANCED_SETUP.md](ADVANCED_SETUP.md). The concise installer reference is in [INSTALL.md](INSTALL.md).

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

FinanceCanvas minimizes/blocks full:

- card numbers;
- bank-account numbers;
- Aadhaar/VID;
- PAN;
- passport/tax identifiers.

Accounts/cards normally use masked values or last four digits.

### Private financial data — normally importable

FinanceCanvas is designed to persist the structured finance data needed for analysis, including:

- profile/full name;
- already-masked card/account identifier;
- transactions, merchants, amounts and categories;
- statement dates;
- balances and credit limits;
- total/minimum due and due dates;
- rewards and finance-related summary values.

This data is private/confidential, but its presence is **not** a reason to refuse a normal statement import.

Mailing/email/contact data is excluded by default when it is not needed for a supported finance feature. The original source PDF/image/spreadsheet is not intentionally stored.

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

The 0.1.5 Skill bundles API v17, database-only transaction analysis and permanent clarification workflows. Reinstall the latest Skill with:

```bash
npx --yes --prefer-online github:niravraychura/financecanvas#main
```

Then say: "Initialize FinanceCanvas using my existing Supabase project. Check the schema and apply only missing FinanceCanvas upgrades; preserve all existing data." Skill installation copies code/instructions; it does not reset, migrate or replace your database automatically. See [references/UPGRADING.md](references/UPGRADING.md).


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
| [REPOSITORY_METADATA.md](REPOSITORY_METADATA.md) | Canonical GitHub description/topics/social-preview copy |
| [CITATION.cff](CITATION.cff) | Citation metadata |
| [LICENSE](LICENSE) | Apache-2.0 license |
| [THIRD_PARTY.md](THIRD_PARTY.md) | Third-party dependency notice |
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

FinanceCanvas is licensed under the [Apache License 2.0](LICENSE).

Apache-2.0 permits private use, modification, distribution and commercial use subject to its terms, and includes an explicit patent grant. See [NOTICE](NOTICE) and [THIRD_PARTY.md](THIRD_PARTY.md) for attribution/dependency information.
