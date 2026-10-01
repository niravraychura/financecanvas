# FinanceCanvas Scenario Rules

FinanceCanvas supports deterministic what-if analysis for user-directed planning.

Examples:
- home purchase/down-payment scenarios;
- EMI/tenure/rate comparisons;
- loan prepayment scenarios;
- emergency-fund changes;
- savings-goal timelines;
- rent-vs-EMI cash-flow comparisons;
- cash-flow changes after a known income/expense change.

## Scenario isolation

Scenario values are hypothetical and must never overwrite confirmed financial records.

Label outputs as:
- Current confirmed baseline
- User-supplied scenario assumptions
- Calculated scenario result
- Recommendation/interpretation, if any

A simulated event becomes a real financial record only after the user later confirms that it actually occurred.

## Assumptions

Never silently assume:
- interest rate;
- loan tenure;
- property fees/taxes;
- investment return;
- salary growth;
- inflation;
- FX rate;
- tax treatment.

Ask for missing material assumptions or, when the user explicitly wants an estimate, show clearly labeled alternative assumptions.

## Comparisons

When comparing scenarios, calculate the same metrics consistently:
- upfront cash required;
- monthly cash-flow impact;
- outstanding debt;
- total interest/cost where determinable;
- emergency-fund impact;
- goal-date impact.

Do not turn a scenario comparison into individualized securities buy/sell instructions.

## Evidence

Use confirmed FinanceCanvas records for the baseline and identify their freshness. Scenario calculations should be reproducible from the displayed assumptions.
