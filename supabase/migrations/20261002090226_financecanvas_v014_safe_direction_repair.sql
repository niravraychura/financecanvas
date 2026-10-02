-- Restored from deployed migration 20261002081602 (financecanvas_v014_safe_direction_repair).

create or replace function public.financecanvas_repair_transaction_direction_batch(
  p_workspace_id uuid,
  p_import_id uuid,
  p_rows jsonb
)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog','public','extensions'
as $function$
declare
  r jsonb;
  v public.transactions%rowtype;
  v_new_direction text;
  v_new_description text;
  v_norm_ws text;
  v_norm_acc text;
  v_norm_date text;
  v_norm_ref text;
  v_norm_desc text;
  v_amount text;
  v_currency text;
  v_json text;
  v_fp text;
  updated_ids jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'rows must be an array';
  end if;

  for r in select value from jsonb_array_elements(p_rows)
  loop
    select *
    into strict v
    from public.transactions t
    where t.workspace_id=p_workspace_id
      and t.import_id=p_import_id
      and t.deleted_at is null
      and t.transaction_reference=(r->>'transaction_reference');

    if nullif(r->>'expected_old_direction','') is not null
       and v.direction <> r->>'expected_old_direction' then
      raise exception 'old direction mismatch for reference %',r->>'transaction_reference';
    end if;
    if nullif(r->>'posted_date','') is not null
       and v.posted_date <> (r->>'posted_date')::date then
      raise exception 'date mismatch for reference %',r->>'transaction_reference';
    end if;
    if nullif(r->>'amount','') is not null
       and v.amount <> (r->>'amount')::numeric then
      raise exception 'amount mismatch for reference %',r->>'transaction_reference';
    end if;

    v_new_direction := r->>'new_direction';
    if v_new_direction not in ('debit','credit','transfer') then
      raise exception 'invalid new direction for reference %',r->>'transaction_reference';
    end if;
    v_new_description := coalesce(nullif(r->>'raw_description',''),v.raw_description);

    v_norm_ws := regexp_replace(lower(btrim(p_workspace_id::text)),'\s+',' ','g');
    v_norm_acc := regexp_replace(lower(btrim(v.account_id::text)),'\s+',' ','g');
    v_norm_date := regexp_replace(lower(btrim(v.posted_date::text)),'\s+',' ','g');
    v_amount := to_char(v.amount,'FM999999999999999999990.00');
    v_currency := upper(coalesce(nullif(v.currency,''),'INR'));
    v_norm_ref := regexp_replace(lower(btrim(coalesce(v.transaction_reference,''))),'\s+',' ','g');
    v_norm_desc := regexp_replace(lower(btrim(coalesce(v_new_description,''))),'\s+',' ','g');

    v_json :=
      '{"workspace_id":' || to_json(v_norm_ws)::text ||
      ',"account_id":' || to_json(v_norm_acc)::text ||
      ',"posted_date":' || to_json(v_norm_date)::text ||
      ',"amount":' || to_json(v_amount)::text ||
      ',"currency":' || to_json(v_currency)::text ||
      ',"direction":' || to_json(v_new_direction)::text ||
      ',"reference":' || to_json(v_norm_ref)::text ||
      ',"raw_description":' || to_json(v_norm_desc)::text ||
      '}';

    v_fp := encode(digest(v_json,'sha256'),'hex');

    update public.transactions
    set direction=v_new_direction,
        raw_description=v_new_description,
        base_fingerprint=v_fp,
        fingerprint=v_fp,
        normalized_values=coalesce(normalized_values,'{}'::jsonb) ||
          jsonb_build_object('financecanvas_direction_repair',
            jsonb_build_object('repaired',true,'source','statement_balance_validation','repaired_at',now())),
        updated_at=now()
    where id=v.id;

    insert into public.audit_log(
      workspace_id,action,target_table,target_id,before_snapshot,after_snapshot,reason,metadata
    ) values (
      p_workspace_id,
      'repair_transaction_direction',
      'transactions',
      v.id,
      jsonb_build_object('direction',v.direction,'raw_description',v.raw_description,'base_fingerprint',v.base_fingerprint),
      jsonb_build_object('direction',v_new_direction,'raw_description',v_new_description,'base_fingerprint',v_fp),
      'Direction corrected from source statement balance movement',
      jsonb_build_object('import_id',p_import_id,'transaction_reference',v.transaction_reference,'data_minimized',true)
    );

    updated_ids := updated_ids || to_jsonb(v.id);
  end loop;

  return jsonb_build_object('count',jsonb_array_length(updated_ids),'updated_ids',updated_ids);
end;
$function$;

revoke all on function public.financecanvas_repair_transaction_direction_batch(uuid,uuid,jsonb)
  from public, anon, authenticated;
grant execute on function public.financecanvas_repair_transaction_direction_batch(uuid,uuid,jsonb)
  to service_role;
