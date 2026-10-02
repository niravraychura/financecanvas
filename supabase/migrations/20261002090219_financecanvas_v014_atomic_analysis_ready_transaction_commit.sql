-- Restored from deployed migration 20261002074916 (financecanvas_v014_atomic_analysis_ready_transaction_commit).

create or replace function public.financecanvas_commit_transaction_batch(
  p_workspace_id uuid,
  p_rows jsonb,
  p_reviews jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public'
as $function$
declare
  r jsonb;
  v_id uuid;
  inserted_ids jsonb := '[]'::jsonb;
  import_ids uuid[] := '{}';
  v_import uuid;
  v_requires_description boolean;
begin
  if jsonb_typeof(p_rows) <> 'array' or jsonb_typeof(p_reviews) <> 'array' then
    raise exception 'rows/reviews must be arrays';
  end if;

  for r in select value from jsonb_array_elements(p_reviews)
  loop
    insert into public.duplicate_reviews(
      workspace_id, existing_transaction_id, incoming_fingerprint, duplicate_type,
      decision, reason, incoming_snapshot, difference
    ) values (
      p_workspace_id,
      nullif(r->>'existing_transaction_id','')::uuid,
      r->>'incoming_fingerprint',
      r->>'duplicate_type',
      r->>'decision',
      nullif(r->>'reason',''),
      coalesce(r->'incoming_snapshot','{}'::jsonb),
      coalesce(r->'difference','{}'::jsonb)
    );
  end loop;

  for r in select value from jsonb_array_elements(p_rows)
  loop
    if (r->>'workspace_id')::uuid <> p_workspace_id then
      raise exception 'workspace mismatch';
    end if;

    v_import := nullif(r->>'import_id','')::uuid;
    if v_import is not null and not (v_import = any(import_ids)) then
      import_ids := array_append(import_ids,v_import);
    end if;

    if v_import is not null then
      select (
        lower(coalesce(i.detected_document_type,'') || ' ' || coalesce(i.source_type,'')) ~
        '(statement|bank|credit.?card|overdraft|wallet|brokerage)'
      )
      into v_requires_description
      from public.imports i
      where i.id=v_import and i.workspace_id=p_workspace_id and i.deleted_at is null;

      if coalesce(v_requires_description,false)
         and nullif(btrim(coalesce(r->>'raw_description','')),'') is null then
        raise exception 'ANALYSIS_DATA_INCOMPLETE: statement transaction narration/raw_description is required';
      end if;
    end if;

    insert into public.transactions(
      workspace_id, profile_id, account_id, import_id, posted_date, transaction_date,
      amount, currency, direction, raw_description, merchant_normalized, transaction_reference,
      category, subcategory, purpose, confidence, confirmation_status,
      balance_after, source_sequence,
      raw_values, normalized_values, base_fingerprint, fingerprint,
      duplicate_of_transaction_id, duplicate_override_reason, duplicate_override_at
    ) values (
      p_workspace_id,
      nullif(r->>'profile_id','')::uuid,
      (r->>'account_id')::uuid,
      v_import,
      (r->>'posted_date')::date,
      nullif(r->>'transaction_date','')::date,
      (r->>'amount')::numeric,
      coalesce(nullif(r->>'currency',''),'INR'),
      r->>'direction',
      nullif(r->>'raw_description',''),
      nullif(r->>'merchant_normalized',''),
      nullif(r->>'transaction_reference',''),
      nullif(r->>'category',''),
      nullif(r->>'subcategory',''),
      nullif(r->>'purpose',''),
      nullif(r->>'confidence','')::numeric,
      coalesce(nullif(r->>'confirmation_status',''),'confirmed'),
      nullif(r->>'balance_after','')::numeric,
      nullif(r->>'source_sequence','')::integer,
      coalesce(r->'raw_values','{}'::jsonb),
      coalesce(r->'normalized_values','{}'::jsonb),
      r->>'base_fingerprint',
      r->>'fingerprint',
      nullif(r->>'duplicate_of_transaction_id','')::uuid,
      nullif(r->>'duplicate_override_reason',''),
      nullif(r->>'duplicate_override_at','')::timestamptz
    )
    returning id into v_id;

    inserted_ids := inserted_ids || to_jsonb(v_id);

    insert into public.audit_log(
      workspace_id,action,target_table,target_id,after_snapshot,reason,metadata
    ) values (
      p_workspace_id,
      case when nullif(r->>'duplicate_override_reason','') is null
        then 'create_transaction' else 'create_transaction_duplicate_override' end,
      'transactions',
      v_id,
      jsonb_build_object(
        'id',v_id,'posted_date',r->>'posted_date','amount',r->>'amount',
        'currency',r->>'currency','direction',r->>'direction','category',r->>'category',
        'account_id',r->>'account_id','balance_after',r->>'balance_after','source_sequence',r->>'source_sequence',
        'description_retained',nullif(r->>'raw_description','') is not null
      ),
      nullif(r->>'duplicate_override_reason',''),
      jsonb_build_object('data_minimized',true,'atomic_batch',true,'database_first_analysis',true)
    );

    insert into public.data_freshness(workspace_id,account_id,confirmed_through,last_import_at)
    values(p_workspace_id,(r->>'account_id')::uuid,(r->>'posted_date')::date,now())
    on conflict(workspace_id,account_id) do update
      set confirmed_through=greatest(public.data_freshness.confirmed_through,excluded.confirmed_through),
          last_import_at=excluded.last_import_at;
  end loop;

  if cardinality(import_ids) > 0 then
    update public.imports i
      set status='committed',
          committed_at=coalesce(i.committed_at,now()),
          record_count=(select count(*) from public.transactions t where t.import_id=i.id and t.deleted_at is null),
          analysis_ready=not exists (
            select 1
            from public.transactions t
            where t.import_id=i.id
              and t.deleted_at is null
              and nullif(btrim(t.raw_description),'') is null
          ),
          analysis_missing_fields=case
            when exists (
              select 1
              from public.transactions t
              where t.import_id=i.id
                and t.deleted_at is null
                and nullif(btrim(t.raw_description),'') is null
            ) then array['raw_description']::text[]
            else '{}'::text[]
          end,
          analysis_ready_at=case
            when not exists (
              select 1
              from public.transactions t
              where t.import_id=i.id
                and t.deleted_at is null
                and nullif(btrim(t.raw_description),'') is null
            ) then coalesce(i.analysis_ready_at,now())
            else null
          end,
          updated_at=now()
    where i.workspace_id=p_workspace_id and i.id = any(import_ids);
  end if;

  return jsonb_build_object(
    'inserted_ids',inserted_ids,
    'count',jsonb_array_length(inserted_ids),
    'import_ids',to_jsonb(import_ids),
    'database_first_analysis',true
  );
end;
$function$;

revoke all on function public.financecanvas_commit_transaction_batch(uuid,jsonb,jsonb) from public, anon, authenticated;
grant execute on function public.financecanvas_commit_transaction_batch(uuid,jsonb,jsonb) to service_role;
