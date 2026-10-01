-- Applied to FinanceCanvas Supabase as financecanvas_v01_core_3.
create table if not exists public.pending_operations (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 operation_type text not null check(operation_type in ('edit_record','soft_delete_record','permanent_delete_record')),
 target_table text not null, target_id uuid not null, requested_change jsonb not null default '{}'::jsonb,
 before_snapshot jsonb not null default '{}'::jsonb, reason text null,
 status text not null default 'pending' check(status in ('pending','confirmed','cancelled','expired','applied')),
 expires_at timestamptz not null default (now()+interval '24 hours'), created_at timestamptz not null default now(), applied_at timestamptz null);
create index if not exists pending_ops_workspace_idx on public.pending_operations(workspace_id,status,expires_at);

create table if not exists public.duplicate_reviews (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 existing_transaction_id uuid null references public.transactions(id) on delete set null, incoming_fingerprint text not null,
 duplicate_type text not null check(duplicate_type in ('exact','near')),
 decision text not null check(decision in ('skip','add_separate','keep_existing','update_existing','cancel')),
 reason text null, incoming_snapshot jsonb not null default '{}'::jsonb, difference jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now());

create table if not exists public.audit_log (
 id bigint generated always as identity primary key, workspace_id uuid not null references public.workspaces(id) on delete cascade,
 actor_type text not null default 'financecanvas_api', action text not null, target_table text null, target_id uuid null,
 before_snapshot jsonb null, after_snapshot jsonb null, reason text null, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now());
create index if not exists audit_workspace_created_idx on public.audit_log(workspace_id,created_at desc);

create table if not exists public.watch_rules (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, name text not null, rule_type text not null,
 cadence text null, severity text not null default 'notice' check(severity in ('info','notice','warning','critical')),
 configuration jsonb not null default '{}'::jsonb, enabled boolean not null default true, last_run_at timestamptz null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now());

create table if not exists public.watch_findings (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 watch_rule_id uuid null references public.watch_rules(id) on delete set null, profile_id uuid null references public.profiles(id) on delete set null,
 transaction_id uuid null references public.transactions(id) on delete set null, finding_type text not null,
 severity text not null check(severity in ('info','notice','warning','critical')), title text not null, explanation text not null,
 next_steps jsonb not null default '[]'::jsonb, evidence jsonb not null default '{}'::jsonb, finding_fingerprint text null,
 status text not null default 'open' check(status in ('open','expected','investigating','resolved','dismissed')),
 resolution_note text null, created_at timestamptz not null default now(), resolved_at timestamptz null);
create unique index if not exists watch_finding_fingerprint_unique on public.watch_findings(workspace_id,finding_fingerprint) where finding_fingerprint is not null;

create table if not exists public.data_freshness (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 account_id uuid not null references public.accounts(id) on delete cascade, confirmed_through date null, last_import_at timestamptz null,
 expected_frequency_days integer null check(expected_frequency_days is null or expected_frequency_days>0),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(workspace_id,account_id));

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'workspaces','profiles','institutions','accounts','transactions','merchant_aliases','loans','insurance_policies',
  'assets','liabilities','investments','subscriptions','goals','correction_memory','watch_rules','data_freshness'
 ] LOOP
  EXECUTE format('DROP TRIGGER IF EXISTS %I_set_updated_at ON public.%I',t,t);
  EXECUTE format('CREATE TRIGGER %I_set_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()',t,t);
 END LOOP;
END $$;

DO $$
DECLARE t text;
BEGIN
 FOREACH t IN ARRAY ARRAY[
  'workspaces','workspace_members','profiles','institutions','accounts','account_owners','imports','transactions',
  'transaction_splits','merchant_aliases','loans','loan_payments','insurance_policies','assets','liabilities',
  'investments','investment_transactions','subscriptions','goals','correction_memory','pending_operations',
  'duplicate_reviews','audit_log','watch_rules','watch_findings','data_freshness'
 ] LOOP
  EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',t);
  EXECUTE format('REVOKE ALL ON TABLE public.%I FROM anon, authenticated',t);
 END LOOP;
END $$;

create table if not exists public.financecanvas_api_keys (
 id uuid primary key default gen_random_uuid(), label text not null default 'default', key_hash text not null unique,
 active boolean not null default true, created_at timestamptz not null default now(), last_used_at timestamptz null, revoked_at timestamptz null);
alter table public.financecanvas_api_keys enable row level security;
revoke all on table public.financecanvas_api_keys from anon, authenticated;

create table if not exists public.financecanvas_schema (
 singleton boolean primary key default true check(singleton=true), schema_version text not null, applied_at timestamptz not null default now());
insert into public.financecanvas_schema(singleton,schema_version) values(true,'0.1.0')
on conflict(singleton) do update set schema_version=excluded.schema_version, applied_at=now();
