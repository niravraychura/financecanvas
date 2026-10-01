alter table public.imports drop constraint if exists imports_status_check;
alter table public.imports add constraint imports_status_check
check(status in ('received','detected','extracted','validated','needs_review','confirmed','previewed','committed','completed','cancelled','failed'));

alter table public.imports
 add column if not exists detected_document_type text null,
 add column if not exists detected_issuer text null,
 add column if not exists confidence numeric(6,5) null check(confidence is null or confidence between 0 and 1),
 add column if not exists updated_at timestamptz not null default now(),
 add column if not exists completed_at timestamptz null,
 add column if not exists deleted_at timestamptz null;

drop trigger if exists imports_set_updated_at on public.imports;
create trigger imports_set_updated_at before update on public.imports
for each row execute function public.set_updated_at();

create table if not exists public.extracted_fields (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 import_id uuid not null references public.imports(id) on delete cascade, field_key text not null, raw_value text null,
 normalized_value text null, confidence numeric(6,5) null check(confidence is null or confidence between 0 and 1),
 status text not null default 'extracted' check(status in ('extracted','confirmed','rejected','needs_review')),
 issue text null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz null);

create table if not exists public.confirmation_queue (
 id uuid primary key default gen_random_uuid(), workspace_id uuid not null references public.workspaces(id) on delete cascade,
 import_id uuid not null references public.imports(id) on delete cascade, entity_type text not null, entity_key text null,
 question text not null, recommended_action text null, options jsonb not null default '[]'::jsonb,
 confidence numeric(6,5) null check(confidence is null or confidence between 0 and 1),
 status text not null default 'open' check(status in ('open','resolved','dismissed')),
 resolution jsonb null, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 resolved_at timestamptz null, deleted_at timestamptz null);

drop trigger if exists extracted_fields_set_updated_at on public.extracted_fields;
create trigger extracted_fields_set_updated_at before update on public.extracted_fields
for each row execute function public.set_updated_at();
drop trigger if exists confirmation_queue_set_updated_at on public.confirmation_queue;
create trigger confirmation_queue_set_updated_at before update on public.confirmation_queue
for each row execute function public.set_updated_at();

alter table public.extracted_fields enable row level security;
alter table public.confirmation_queue enable row level security;
revoke all on table public.extracted_fields from anon, authenticated;
revoke all on table public.confirmation_queue from anon, authenticated;
revoke all on table public.imports from anon, authenticated;

create index if not exists extracted_fields_import_idx on public.extracted_fields(workspace_id,import_id,status);
create index if not exists confirmation_queue_import_idx on public.confirmation_queue(workspace_id,import_id,status);

create or replace function public.financecanvas_commit_transaction_batch(
 p_workspace_id uuid,p_rows jsonb,p_reviews jsonb default '[]'::jsonb
) returns jsonb
language plpgsql security definer set search_path=pg_catalog,public
as $$
declare r jsonb; v_id uuid; inserted_ids jsonb := '[]'::jsonb;
begin
 if jsonb_typeof(p_rows)<>'array' or jsonb_typeof(p_reviews)<>'array' then raise exception 'rows/reviews must be arrays'; end if;
 for r in select value from jsonb_array_elements(p_reviews) loop
  insert into public.duplicate_reviews(workspace_id,existing_transaction_id,incoming_fingerprint,duplicate_type,decision,reason,incoming_snapshot,difference)
  values(p_workspace_id,nullif(r->>'existing_transaction_id','')::uuid,r->>'incoming_fingerprint',r->>'duplicate_type',r->>'decision',nullif(r->>'reason',''),coalesce(r->'incoming_snapshot','{}'::jsonb),coalesce(r->'difference','{}'::jsonb));
 end loop;
 for r in select value from jsonb_array_elements(p_rows) loop
  if (r->>'workspace_id')::uuid<>p_workspace_id then raise exception 'workspace mismatch'; end if;
  insert into public.transactions(workspace_id,profile_id,account_id,import_id,posted_date,transaction_date,amount,currency,direction,raw_description,merchant_normalized,transaction_reference,category,subcategory,purpose,confidence,confirmation_status,raw_values,normalized_values,base_fingerprint,fingerprint,duplicate_of_transaction_id,duplicate_override_reason,duplicate_override_at)
  values(p_workspace_id,nullif(r->>'profile_id','')::uuid,(r->>'account_id')::uuid,nullif(r->>'import_id','')::uuid,(r->>'posted_date')::date,nullif(r->>'transaction_date','')::date,(r->>'amount')::numeric,coalesce(nullif(r->>'currency',''),'INR'),r->>'direction',r->>'raw_description',r->>'merchant_normalized',r->>'transaction_reference',r->>'category',r->>'subcategory',r->>'purpose',nullif(r->>'confidence','')::numeric,coalesce(nullif(r->>'confirmation_status',''),'confirmed'),coalesce(r->'raw_values','{}'::jsonb),coalesce(r->'normalized_values','{}'::jsonb),r->>'base_fingerprint',r->>'fingerprint',nullif(r->>'duplicate_of_transaction_id','')::uuid,r->>'duplicate_override_reason',nullif(r->>'duplicate_override_at','')::timestamptz)
  returning id into v_id;
  inserted_ids:=inserted_ids||to_jsonb(v_id);
  insert into public.audit_log(workspace_id,action,target_table,target_id,after_snapshot,reason,metadata)
  values(p_workspace_id,case when nullif(r->>'duplicate_override_reason','') is null then 'create_transaction' else 'create_transaction_duplicate_override' end,'transactions',v_id,jsonb_build_object('id',v_id,'posted_date',r->>'posted_date','amount',r->>'amount','currency',r->>'currency','direction',r->>'direction','category',r->>'category','account_id',r->>'account_id'),nullif(r->>'duplicate_override_reason',''),jsonb_build_object('data_minimized',true,'atomic_batch',true));
  insert into public.data_freshness(workspace_id,account_id,confirmed_through,last_import_at)
  values(p_workspace_id,(r->>'account_id')::uuid,(r->>'posted_date')::date,now())
  on conflict(workspace_id,account_id) do update set confirmed_through=greatest(public.data_freshness.confirmed_through,excluded.confirmed_through),last_import_at=excluded.last_import_at;
 end loop;
 return jsonb_build_object('inserted_ids',inserted_ids,'count',jsonb_array_length(inserted_ids));
end;
$$;
revoke all on function public.financecanvas_commit_transaction_batch(uuid,jsonb,jsonb) from public,anon,authenticated;
