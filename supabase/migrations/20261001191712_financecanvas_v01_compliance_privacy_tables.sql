alter table public.accounts drop constraint if exists accounts_identifier_last4_check;
alter table public.accounts add constraint accounts_identifier_last4_check
check (identifier_last4 is null or char_length(identifier_last4) <= 4);

alter table public.audit_log add column if not exists retain_until timestamptz not null default (now() + interval '365 days');

create table if not exists public.processing_consents (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, purpose text not null, notice_version text not null,
 status text not null default 'granted' check(status in ('granted','withdrawn','not_required')),
 granted_at timestamptz null, withdrawn_at timestamptz null, metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now());

create table if not exists public.sensitive_data_events (
 id uuid primary key default gen_random_uuid(), workspace_id uuid null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null, source_type text null,
 detected_categories text[] not null default '{}', risk_level text not null check(risk_level in ('notice','warning','critical')),
 action text not null check(action in ('warned','redacted','rejected','accepted_minimized')),
 user_confirmed boolean not null default false, next_steps_shown boolean not null default false,
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now(),
 retain_until timestamptz not null default (now() + interval '180 days'));

create table if not exists public.security_events (
 id bigint generated always as identity primary key, workspace_id uuid null references public.workspaces(id) on delete cascade,
 event_type text not null, severity text not null default 'info' check(severity in ('info','notice','warning','critical')),
 actor_type text null, metadata jsonb not null default '{}'::jsonb, occurred_at timestamptz not null default now(),
 retain_until timestamptz not null default (now() + interval '365 days'));

create table if not exists public.privacy_requests (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 profile_id uuid null references public.profiles(id) on delete set null,
 request_type text not null check(request_type in ('access','correction','update','erasure','export','withdraw_consent','restriction','other')),
 status text not null default 'open' check(status in ('open','in_progress','completed','declined','cancelled')),
 request_note text null, response_note text null, requested_at timestamptz not null default now(), completed_at timestamptz null);

create table if not exists public.breach_incidents (
 id uuid primary key default gen_random_uuid(), workspace_id uuid null references public.workspaces(id) on delete set null,
 status text not null default 'investigating' check(status in ('investigating','contained','resolved','closed')),
 severity text not null check(severity in ('notice','warning','critical')), summary text not null,
 affected_data_categories text[] not null default '{}', discovered_at timestamptz not null, contained_at timestamptz null,
 affected_people_notified_at timestamptz null, cert_in_reported_at timestamptz null,
 data_protection_board_reported_at timestamptz null, other_authority_reports jsonb not null default '{}'::jsonb,
 remediation_summary text null, created_at timestamptz not null default now(),
 retain_until timestamptz not null default (now() + interval '365 days'));

create table if not exists public.financecanvas_compliance_settings (
 singleton boolean primary key default true check(singleton=true),
 deployment_mode text not null default 'prototype' check(deployment_mode in ('prototype','personal','production')),
 connection_mode text not null default 'connector_first' check(connection_mode in ('connector_first','api_adapter')),
 primary_region text null, production_ready boolean not null default false,
 cert_in_log_retention_days integer not null default 180 check(cert_in_log_retention_days >= 180),
 source_document_persistence boolean not null default false, updated_at timestamptz not null default now());

insert into public.financecanvas_compliance_settings(singleton,deployment_mode,connection_mode,primary_region,production_ready)
values(true,'prototype','connector_first','ap-south-1',false)
on conflict(singleton) do update set connection_mode='connector_first',primary_region='ap-south-1',production_ready=false,updated_at=now();

do $$
declare t text;
begin
 foreach t in array array['processing_consents','sensitive_data_events','security_events','privacy_requests','breach_incidents','financecanvas_compliance_settings']
 loop
   execute format('alter table public.%I enable row level security',t);
   execute format('revoke all on table public.%I from anon, authenticated',t);
 end loop;
end $$;

create index if not exists processing_consents_workspace_idx on public.processing_consents(workspace_id,created_at desc);
create index if not exists sensitive_events_workspace_idx on public.sensitive_data_events(workspace_id,created_at desc);
create index if not exists security_events_workspace_idx on public.security_events(workspace_id,occurred_at desc);
create index if not exists privacy_requests_workspace_idx on public.privacy_requests(workspace_id,requested_at desc);
create index if not exists breach_incidents_discovered_idx on public.breach_incidents(discovered_at desc);
