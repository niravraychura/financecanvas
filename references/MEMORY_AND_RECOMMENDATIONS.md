# FinanceCanvas Financial Memory and Recommendations

## Persistent financial preferences

FinanceCanvas may persist user-confirmed financial preferences that improve future analysis, such as:
- emergency-fund target/policy;
- risk-profile wording supplied or confirmed by the user;
- savings priorities;
- payment/card strategy preferences;
- preferred base currency;
- budgeting conventions;
- goal assumptions;
- family/shared-expense rules.

Use `upsert_financial_preference`.

Never store authentication secrets, government identifiers, card/account credentials, or other blocked sensitive values as a "preference".

Derived preferences must be labeled `derived` and should not silently override a user-confirmed preference.

## Recommendation history

Material recommendations may be stored through `record_recommendation` when they are useful for future comparison/follow-up.

Store:
- recommendation type/title/summary;
- rationale;
- evidence;
- assumptions;
- confidence;
- status.

Recommendations are not database facts. They remain AI recommendations and should be distinguished from confirmed financial records.

If the user rejects/dismisses a recommendation, preserve that status so FinanceCanvas does not repeatedly present the same recommendation without new evidence.

## Investment boundary

Recommendation history does not expand FinanceCanvas's regulatory permissions. The SEBI/investment-advice restrictions in SKILL.md and COMPLIANCE.md still apply.
