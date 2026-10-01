# FinanceCanvas Release Checklist

Before tagging/releasing a FinanceCanvas version:

- [ ] CI passes.
- [ ] SECURITY_CHECKLIST.md completed for the release diff.
- [ ] Supabase migrations are represented in GitHub.
- [ ] Live Edge Function source matches GitHub.
- [ ] Security advisors reviewed.
- [ ] Active API keys reviewed.
- [ ] No secrets/personal data in repository or release assets.
- [ ] README/SKILL/CHANGELOG updated.
- [ ] Threat model reviewed for changed trust boundaries.
- [ ] Compliance review performed if behavior/jurisdiction/business model changed.
- [ ] production_ready remains false unless every COMPLIANCE.md production-gate item is complete.
- [ ] Release notes document security-impact result: PASS / PASS WITH ACCEPTED RISK / BLOCKED.
