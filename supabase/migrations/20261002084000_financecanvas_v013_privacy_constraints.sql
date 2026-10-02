alter table public.accounts
  drop constraint if exists accounts_identifier_last4_length_check;
alter table public.accounts
  add constraint accounts_identifier_last4_length_check
  check(identifier_last4 is null or char_length(identifier_last4) between 1 and 4);

alter table public.loans
  drop constraint if exists loans_identifier_last4_length_check;
alter table public.loans
  add constraint loans_identifier_last4_length_check
  check(identifier_last4 is null or char_length(identifier_last4) between 1 and 4);

alter table public.insurance_policies
  drop constraint if exists insurance_policy_identifier_last4_length_check;
alter table public.insurance_policies
  add constraint insurance_policy_identifier_last4_length_check
  check(policy_identifier_last4 is null or char_length(policy_identifier_last4) between 1 and 4);

update public.financecanvas_schema
set schema_version='0.1.3', applied_at=now()
where singleton=true;
