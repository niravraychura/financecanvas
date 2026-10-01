# FinanceCanvas Compliance Baseline

> This document is a product/compliance engineering checklist, not legal advice. A qualified lawyer should review the exact business model and launch jurisdictions before a public/commercial release.

## Current status

FinanceCanvas v0.1 is intentionally marked:

- deployment mode: prototype
- connection mode: connector-first
- production-ready: false
- primary Supabase region: ap-south-1
- source-document persistence: disabled

For a purely personal/domestic installation, Section 3(c)(i) of India's Digital Personal Data Protection Act, 2023 excludes personal data processed by an individual for a personal or domestic purpose. Do not rely on this exclusion for a commercial/customer-facing service.

## India: core privacy/data protection

Primary references:

- Digital Personal Data Protection Act, 2023:
  https://www.indiacode.nic.in/handle/123456789/22037
- Digital Personal Data Protection Rules, 2025:
  https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa
- CERT-In Directions (cyber incident/logging obligations):
  https://www.cert-in.org.in/

Before a public/commercial deployment:

1. Identify the operator/Data Fiduciary and publish contact/grievance details.
2. Give a clear notice describing the personal data, purpose, rights and complaint mechanism.
3. Use a lawful purpose and obtain clear consent where consent is the chosen basis.
4. Provide consent withdrawal and rights workflows.
5. Apply data minimisation and purpose limitation.
6. Keep data accurate where it is used for decisions or disclosed onward.
7. Protect personal data with reasonable technical/organisational safeguards.
8. Have a documented personal-data-breach response and notification process.
9. Define retention schedules and erase data when the purpose ends unless law requires retention.
10. Have valid processor/vendor contracts and assess cross-border restrictions before relying on a non-Indian processor/location.
11. Validate required security/log retention before production. FinanceCanvas keeps its compliance/security records for conservative periods, but vendor/platform logs must also be reviewed.

## Existing Indian sensitive-data/security baseline

Financial information is inherently high risk. FinanceCanvas therefore applies stronger controls even when a specific statutory definition changes over time:

- no banking passwords or authentication credentials;
- no PIN/one-time authentication secrets;
- no card security codes;
- no source-document persistence in FinanceCanvas;
- masked/last-four card and account identifiers;
- structured-data confirmation before persistence;
- audit and duplicate controls;
- access restricted to the controlled application/connector path.

## RBI / payments / account aggregation boundary

FinanceCanvas v0.1 is not a payment system, bank, Payment Aggregator, or RBI Account Aggregator.

Reference:
- RBI Account Aggregator Master Directions:
  https://www.rbi.org.in/Scripts/BS_ViewMasDirections.aspx?id=10598
- RBI restriction on storage of actual card data:
  https://www.rbi.org.in/scripts/NotificationUser.aspx?Id=12345

Do not add features that:
- hold or transfer customer funds;
- initiate payments without an appropriately regulated/provider-controlled workflow;
- collect bank login credentials;
- scrape authenticated bank portals;
- represent FinanceCanvas as an Account Aggregator;
- store full card credentials/card-on-file data.

If bank-account aggregation is added for customers at scale, use an appropriately authorized bank/provider or RBI Account Aggregator/FIU arrangement and perform a new regulatory review before release.

## SEBI boundary

FinanceCanvas may perform:
- factual portfolio summaries;
- deterministic calculations;
- user-directed scenario analysis;
- general financial education;
- neutral explanation of risks and diversification;
- record keeping.

FinanceCanvas v0.1 must not be marketed or operated as a registered Investment Adviser or Research Analyst and must not provide individualized securities buy/sell/hold recommendations for consideration unless the operator has completed the required SEBI registration and compliance review.

References:
- SEBI Investment Advisers Regulations:
  https://www.sebi.gov.in/legal/regulations/nov-2025/securities-and-exchange-board-of-india-investment-advisers-regulations-2013-and-securities-last-amended-on-november-25-2025-_98246.html
- SEBI Master Circular for Investment Advisers, 6 Feb 2026:
  https://www.sebi.gov.in/legal/master-circulars/feb-2026/master-circular-for-investment-advisers_99569.html

## Sensitive upload response

If an upload contains a high-risk secret:

1. show an immediate warning in chat;
2. do not repeat the secret;
3. exclude it from structured persistence;
4. minimize any audit/event record to category/action only;
5. recommend an appropriate next step:
   - password/passcode exposure -> change it;
   - API/private key exposure -> rotate/revoke it;
   - card/payment credential exposure -> contact issuer, consider blocking/replacing as appropriate;
   - one-time code/PIN exposure -> never retain it and advise user not to reuse/share it.

For identity/government identifiers, mask/minimize and do not persist them in v0.1.

Important: FinanceCanvas does not intentionally save the uploaded source file to its own database, but the chat/LLM host may retain the upload under its own policy. State this clearly.

## Incident response

For suspected unauthorized access/data leakage:

1. contain the incident;
2. revoke/rotate affected credentials;
3. preserve only necessary evidence;
4. record discovery/containment times;
5. identify affected data/people;
6. determine whether CERT-In, the Data Protection Board/affected individuals, a financial regulator, customers, or another authority must be notified;
7. send notices within the legally applicable time limit;
8. document remediation and lessons learned.

Do not put raw secrets into incident records.

## International baseline

If FinanceCanvas is offered outside India, do not assume Indian compliance is sufficient.

### EU/EEA — GDPR
Before launch, review:
- lawful basis and transparent notices;
- data minimisation and storage limitation;
- privacy by design/default;
- processor agreements;
- data-subject rights;
- security appropriate to risk;
- personal-data-breach assessment/notification;
- international-transfer mechanism;
- restrictions around solely automated decisions with legal/similarly significant effects.

Official source:
https://eur-lex.europa.eu/eli/reg/2016/679/oj

### United Kingdom
Apply the UK GDPR/Data Protection Act 2018 equivalent baseline, including privacy-by-design and breach assessment.

Official guidance:
https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/

### California
If thresholds/scope apply, assess CCPA/CPRA notice, access/deletion/correction, sensitive personal information, service-provider/contract and reasonable-security obligations.

Official guidance:
https://oag.ca.gov/privacy/ccpa

## Production gate

Do not set FinanceCanvas to production-ready until all relevant items are complete:

- [ ] Operator/legal entity identified
- [ ] Launch jurisdictions identified
- [ ] Privacy notice approved
- [ ] Consent/lawful-purpose flow approved
- [ ] Grievance/privacy contact published
- [ ] Data inventory and purpose map completed
- [ ] Retention schedule approved
- [ ] User access/correction/export/erasure workflows tested
- [ ] Processor/vendor contracts and subprocessors reviewed
- [ ] Cross-border/data-residency analysis completed
- [ ] Incident response tested
- [ ] Required security/log retention validated
- [ ] Backup/disaster recovery reviewed
- [ ] Bank/payment/AA features reviewed if present
- [ ] SEBI adviser/research-analyst boundary reviewed if investment recommendations are present
- [ ] Security testing completed
- [ ] Legal review completed for the actual commercial model
