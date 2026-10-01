# FinanceCanvas Privacy Notice Template

> Template only. Customize the operator identity, contact details, purposes, jurisdictions, retention periods and subprocessors before a public/commercial launch.

## What FinanceCanvas processes

Depending on what the user chooses to provide, FinanceCanvas may process structured information about transactions, accounts, balances, loans, insurance, assets, liabilities, investments, subscriptions, financial goals, and household/profile ownership.

FinanceCanvas is designed to minimize identifiers. It normally uses masked or last-four account/card identifiers.

## What FinanceCanvas does not intentionally store

FinanceCanvas v0.1 does not intentionally persist:
- the original uploaded statement/image/spreadsheet/document;
- authentication/payment secrets;
- banking login credentials;
- full card numbers;
- full bank account numbers;
- Aadhaar/VID, PAN or passport values.

If prohibited high-risk information is detected, FinanceCanvas should warn the user and reject/redact it before persistence.

## Why information is processed

Typical purposes:
- organize the user's financial records;
- answer user-requested financial questions;
- detect duplicate/inconsistent records;
- perform user-requested calculations/scenarios;
- monitor user-configured alerts and potential unusual charges;
- maintain security/audit history;
- export/delete/correct data at the user's request.

Do not repurpose personal data for advertising, sale, unrelated profiling, or model training unless a separate lawful, transparent and explicitly approved arrangement exists.

## Source uploads and chat-host retention

FinanceCanvas does not intentionally copy the original source document into its own database. The application/LLM/chat provider through which a user uploads a document may independently retain that upload according to its own privacy and retention settings. The FinanceCanvas operator must disclose that distinction.

## User controls

Provide practical mechanisms for:
- access;
- correction/update;
- structured export;
- consent withdrawal where consent is the basis;
- deletion/erasure subject to legal/security retention requirements;
- grievance/privacy questions.

## Security

FinanceCanvas uses controlled database access, data minimization, duplicate protection, two-step edits/deletions, audit history, and sensitive-data rejection/redaction.

No system is risk-free. Users should not upload authentication secrets and should promptly rotate/revoke a credential if it has been exposed.

## Contact

Before production launch, replace this section with the operator's:
- legal/business name;
- privacy/grievance contact;
- address/contact method where required;
- escalation/complaint instructions;
- regulator/Board complaint information where applicable.
