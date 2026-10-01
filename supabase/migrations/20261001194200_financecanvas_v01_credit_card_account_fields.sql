alter table public.accounts
  add column if not exists credit_limit numeric(20,4) null check(credit_limit is null or credit_limit >= 0),
  add column if not exists annual_fee numeric(20,4) null check(annual_fee is null or annual_fee >= 0),
  add column if not exists annual_fee_waiver_spend numeric(20,4) null check(annual_fee_waiver_spend is null or annual_fee_waiver_spend >= 0);

revoke all on table public.accounts from anon, authenticated;
