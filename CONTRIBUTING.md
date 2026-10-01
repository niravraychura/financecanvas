# Contributing to FinanceCanvas

FinanceCanvas handles highly sensitive financial information. Security and privacy are part of correctness.

## Required workflow

1. Make the smallest necessary change.
2. Use fictional/synthetic data in tests/examples.
3. Run the test suite and security check.
4. Complete the relevant items in SECURITY_CHECKLIST.md.
5. Update documentation/threat model when behavior or trust boundaries change.
6. Never merge a BLOCKED security review.

## Pull requests

Every PR should state:
- what changed;
- financial-data/security impact;
- whether schema/API/Skill behavior changed;
- security-check result;
- any accepted risk.

Do not include secrets or personal financial records in issues, PR descriptions, logs or screenshots.
