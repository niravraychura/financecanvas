-- Restored from deployed migration 20261002084828 (financecanvas_v015_transaction_clarification_memory).

create table if not exists public.transaction_clarifications (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  transaction_id uuid not null references public.transactions(id) on delete cascade,
  merchant_normalized text,
  category text,
  subcategory text,
  purpose text,
  context_note text not null,
  scope text not null default 'transaction'
    check (scope in ('transaction','month','date_range','global')),
  effective_from date,
  effective_to date,
  confirmed_by_user boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,transaction_id)
);

create index if not exists transaction_clarifications_workspace_idx
  on public.transaction_clarifications(workspace_id,transaction_id);

alter table public.transaction_clarifications enable row level security;
revoke all on public.transaction_clarifications from anon, authenticated;

comment on table public.transaction_clarifications is
  'Authoritative user-confirmed semantic clarification for a transaction. The transaction row remains the primary analysis record; this table preserves why a classification/merchant meaning was changed.';

create or replace function public.financecanvas_commit_transaction_clarifications(
  p_workspace_id uuid,
  p_rows jsonb,
  p_aliases jsonb default '[]'::jsonb,
  p_memories jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public'
as $function$
declare
  r jsonb;
  a jsonb;
  m jsonb;
  v public.transactions%rowtype;
  v_after public.transactions%rowtype;
  v_merchant text;
  v_category text;
  v_subcategory text;
  v_purpose text;
  v_note text;
  v_scope text;
  v_metadata jsonb;
  updated_ids jsonb := '[]'::jsonb;
  alias_ids jsonb := '[]'::jsonb;
  memory_ids jsonb := '[]'::jsonb;
  v_id uuid;
begin
  if jsonb_typeof(p_rows) <> 'array'
     or jsonb_typeof(p_aliases) <> 'array'
     or jsonb_typeof(p_memories) <> 'array' then
    raise exception 'rows, aliases and memories must be arrays';
  end if;

  for r in select value from jsonb_array_elements(p_rows)
  loop
    select *
    into strict v
    from public.transactions t
    where t.id=(r->>'transaction_id')::uuid
      and t.workspace_id=p_workspace_id
      and t.deleted_at is null;

    v_merchant := case when r ? 'merchant_normalized'
      then nullif(btrim(r->>'merchant_normalized'),'') else v.merchant_normalized end;
    v_category := case when r ? 'category'
      then nullif(btrim(r->>'category'),'') else v.category end;
    v_subcategory := case when r ? 'subcategory'
      then nullif(btrim(r->>'subcategory'),'') else v.subcategory end;
    v_purpose := case when r ? 'purpose'
      then nullif(btrim(r->>'purpose'),'') else v.purpose end;
    v_note := nullif(btrim(r->>'context_note'),'');
    if v_note is null then
      raise exception 'context_note is required for transaction clarification';
    end if;
    v_scope := coalesce(nullif(r->>'scope',''),'transaction');
    if v_scope not in ('transaction','month','date_range','global') then
      raise exception 'invalid clarification scope';
    end if;
    v_metadata := coalesce(r->'metadata','{}'::jsonb);

    update public.transactions
    set merchant_normalized=v_merchant,
        category=v_category,
        subcategory=v_subcategory,
        purpose=v_purpose,
        confidence=case when r ? 'confidence'
          then nullif(r->>'confidence','')::numeric else confidence end,
        confirmation_status='confirmed',
        normalized_values=coalesce(normalized_values,'{}'::jsonb) ||
          jsonb_build_object(
            'financecanvas_clarification',
            jsonb_build_object(
              'confirmed_by_user',true,
              'context_note',v_note,
              'scope',v_scope,
              'clarified_at',now(),
              'metadata',v_metadata
            )
          ),
        updated_at=now()
    where id=v.id
    returning * into v_after;

    insert into public.transaction_clarifications(
      workspace_id,transaction_id,merchant_normalized,category,subcategory,purpose,
      context_note,scope,effective_from,effective_to,confirmed_by_user,metadata
    ) values (
      p_workspace_id,v.id,v_merchant,v_category,v_subcategory,v_purpose,
      v_note,v_scope,
      nullif(r->>'effective_from','')::date,
      nullif(r->>'effective_to','')::date,
      true,v_metadata
    )
    on conflict(workspace_id,transaction_id) do update
      set merchant_normalized=excluded.merchant_normalized,
          category=excluded.category,
          subcategory=excluded.subcategory,
          purpose=excluded.purpose,
          context_note=excluded.context_note,
          scope=excluded.scope,
          effective_from=excluded.effective_from,
          effective_to=excluded.effective_to,
          confirmed_by_user=true,
          metadata=excluded.metadata,
          updated_at=now();

    insert into public.audit_log(
      workspace_id,action,target_table,target_id,before_snapshot,after_snapshot,reason,metadata
    ) values (
      p_workspace_id,'user_transaction_clarification','transactions',v.id,
      jsonb_build_object(
        'merchant_normalized',v.merchant_normalized,'category',v.category,
        'subcategory',v.subcategory,'purpose',v.purpose
      ),
      jsonb_build_object(
        'merchant_normalized',v_after.merchant_normalized,'category',v_after.category,
        'subcategory',v_after.subcategory,'purpose',v_after.purpose
      ),
      v_note,
      jsonb_build_object('confirmed_by_user',true,'scope',v_scope,'data_minimized',true)
    );

    updated_ids := updated_ids || to_jsonb(v.id);
  end loop;

  for a in select value from jsonb_array_elements(p_aliases)
  loop
    if nullif(btrim(a->>'raw_pattern'),'') is null
       or nullif(btrim(a->>'normalized_merchant'),'') is null then
      raise exception 'raw_pattern and normalized_merchant are required for alias';
    end if;

    insert into public.merchant_aliases(
      workspace_id,raw_pattern,normalized_merchant,category,subcategory,purpose,confirmed_by_user,deleted_at
    ) values (
      p_workspace_id,
      btrim(a->>'raw_pattern'),
      btrim(a->>'normalized_merchant'),
      nullif(btrim(a->>'category'),''),
      nullif(btrim(a->>'subcategory'),''),
      nullif(btrim(a->>'purpose'),''),
      true,null
    )
    on conflict(workspace_id,raw_pattern) do update
      set normalized_merchant=excluded.normalized_merchant,
          category=excluded.category,
          subcategory=excluded.subcategory,
          purpose=excluded.purpose,
          confirmed_by_user=true,
          deleted_at=null,
          updated_at=now()
    returning id into v_id;

    alias_ids := alias_ids || to_jsonb(v_id);
  end loop;

  for m in select value from jsonb_array_elements(p_memories)
  loop
    if nullif(btrim(m->>'correction_type'),'') is null
       or nullif(btrim(m->>'source_value'),'') is null then
      raise exception 'correction_type and source_value are required for correction memory';
    end if;

    insert into public.correction_memory(
      workspace_id,correction_type,source_value,normalized_value,extra,accepted
    ) values (
      p_workspace_id,
      btrim(m->>'correction_type'),
      btrim(m->>'source_value'),
      nullif(btrim(m->>'normalized_value'),''),
      coalesce(m->'extra','{}'::jsonb),
      true
    )
    on conflict(workspace_id,correction_type,source_value) do update
      set normalized_value=excluded.normalized_value,
          extra=excluded.extra,
          accepted=true,
          updated_at=now()
    returning id into v_id;

    memory_ids := memory_ids || to_jsonb(v_id);
  end loop;

  return jsonb_build_object(
    'updated_transaction_ids',updated_ids,
    'transaction_count',jsonb_array_length(updated_ids),
    'merchant_alias_ids',alias_ids,
    'merchant_alias_count',jsonb_array_length(alias_ids),
    'correction_memory_ids',memory_ids,
    'correction_memory_count',jsonb_array_length(memory_ids)
  );
end;
$function$;

revoke all on function public.financecanvas_commit_transaction_clarifications(uuid,jsonb,jsonb,jsonb)
  from public, anon, authenticated;
grant execute on function public.financecanvas_commit_transaction_clarifications(uuid,jsonb,jsonb,jsonb)
  to service_role;

update public.financecanvas_schema
set schema_version='0.1.5', applied_at=now()
where singleton=true;
