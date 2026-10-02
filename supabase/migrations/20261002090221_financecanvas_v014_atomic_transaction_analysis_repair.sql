-- Restored from deployed migration 20261002075016 (financecanvas_v014_atomic_transaction_analysis_repair).

create or replace function public.financecanvas_repair_transaction_analysis_batch(
  p_workspace_id uuid,
  p_import_id uuid,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public'
as $function$
declare
  r jsonb;
  v_id uuid;
  v_existing public.transactions%rowtype;
  updated_ids jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'rows must be an array';
  end if;

  if not exists (
    select 1 from public.imports i
    where i.id=p_import_id and i.workspace_id=p_workspace_id and i.deleted_at is null
  ) then
    raise exception 'import does not belong to workspace';
  end if;

  for r in select value from jsonb_array_elements(p_rows)
  loop
    v_id := nullif(r->>'transaction_id','')::uuid;
    if v_id is null then
      raise exception 'transaction_id is required for repair commit';
    end if;

    select *
    into v_existing
    from public.transactions t
    where t.id=v_id
      and t.workspace_id=p_workspace_id
      and t.import_id=p_import_id
      and t.deleted_at is null;

    if not found then
      raise exception 'transaction does not belong to the specified import/workspace';
    end if;

    if nullif(r->>'posted_date','') is not null
       and v_existing.posted_date <> (r->>'posted_date')::date then
      raise exception 'posted_date mismatch for transaction %',v_id;
    end if;
    if nullif(r->>'amount','') is not null
       and v_existing.amount <> (r->>'amount')::numeric then
      raise exception 'amount mismatch for transaction %',v_id;
    end if;
    if nullif(r->>'direction','') is not null
       and v_existing.direction <> r->>'direction' then
      raise exception 'direction mismatch for transaction %',v_id;
    end if;

    if nullif(btrim(coalesce(r->>'raw_description','')),'') is null then
      raise exception 'ANALYSIS_DATA_INCOMPLETE: raw_description is required for transaction repair';
    end if;

    update public.transactions
    set raw_description=nullif(r->>'raw_description',''),
        merchant_normalized=coalesce(nullif(r->>'merchant_normalized',''),merchant_normalized),
        category=coalesce(nullif(r->>'category',''),category),
        subcategory=coalesce(nullif(r->>'subcategory',''),subcategory),
        purpose=coalesce(nullif(r->>'purpose',''),purpose),
        confidence=coalesce(nullif(r->>'confidence','')::numeric,confidence),
        normalized_values=coalesce(normalized_values,'{}'::jsonb) ||
          coalesce(r->'normalized_values','{}'::jsonb),
        updated_at=now()
    where id=v_id;

    insert into public.audit_log(
      workspace_id,action,target_table,target_id,before_snapshot,after_snapshot,metadata
    ) values (
      p_workspace_id,
      'repair_transaction_analysis_fields',
      'transactions',
      v_id,
      jsonb_build_object(
        'description_present',nullif(btrim(coalesce(v_existing.raw_description,'')),'') is not null,
        'merchant_normalized',v_existing.merchant_normalized,
        'category',v_existing.category,
        'subcategory',v_existing.subcategory
      ),
      jsonb_build_object(
        'description_present',true,
        'merchant_normalized',nullif(r->>'merchant_normalized',''),
        'category',nullif(r->>'category',''),
        'subcategory',nullif(r->>'subcategory','')
      ),
      jsonb_build_object('data_minimized',true,'database_first_analysis',true,'repair',true)
    );

    updated_ids := updated_ids || to_jsonb(v_id);
  end loop;

  update public.imports i
  set analysis_ready=not exists (
        select 1 from public.transactions t
        where t.import_id=i.id and t.deleted_at is null
          and nullif(btrim(t.raw_description),'') is null
      ),
      analysis_missing_fields=case
        when exists (
          select 1 from public.transactions t
          where t.import_id=i.id and t.deleted_at is null
            and nullif(btrim(t.raw_description),'') is null
        ) then array['raw_description']::text[]
        else '{}'::text[]
      end,
      analysis_ready_at=case
        when not exists (
          select 1 from public.transactions t
          where t.import_id=i.id and t.deleted_at is null
            and nullif(btrim(t.raw_description),'') is null
        ) then coalesce(i.analysis_ready_at,now())
        else null
      end,
      updated_at=now()
  where i.id=p_import_id and i.workspace_id=p_workspace_id;

  return jsonb_build_object(
    'updated_ids',updated_ids,
    'count',jsonb_array_length(updated_ids),
    'import_id',p_import_id
  );
end;
$function$;

revoke all on function public.financecanvas_repair_transaction_analysis_batch(uuid,uuid,jsonb)
  from public, anon, authenticated;
grant execute on function public.financecanvas_repair_transaction_analysis_batch(uuid,uuid,jsonb)
  to service_role;
