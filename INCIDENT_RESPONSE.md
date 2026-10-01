# FinanceCanvas Incident Response

## Trigger examples

- suspected unauthorized database/API access;
- secret committed to GitHub;
- sensitive financial data exposed to the wrong person/workspace;
- host/plugin/connector compromise;
- unexpected mass export/deletion;
- leaked runtime credential;
- source documents accidentally persisted.

## Immediate actions

1. Stop further exposure.
2. Revoke/rotate affected credentials.
3. Disable affected runtime integration if necessary.
4. Preserve only the minimum evidence needed for investigation.
5. Never copy raw secrets into incident tickets/logs.
6. Identify affected workspaces/data categories/time window.
7. Determine notification obligations using COMPLIANCE.md and qualified counsel/security personnel when appropriate.
8. Remediate the root cause and run SECURITY_CHECKLIST.md before restoring normal operation.

## GitHub secret exposure

If a real secret is committed:
- revoke/rotate it immediately; deleting the visible file is not enough;
- inspect Git history/forks/actions logs;
- remove it from history where appropriate;
- document the incident without preserving the secret itself.

## Financial credential exposure

If card/bank authentication material was exposed, do not store or repeat it. Give the user appropriate issuer/bank remediation steps.

## Post-incident

- document root cause and impact;
- add a regression test/control;
- update threat model/checklists;
- verify Supabase security advisors;
- verify direct table grants and runtime-key state;
- record whether regulatory/user notifications were required.
