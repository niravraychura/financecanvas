-- Connector-native statement import for BYO Supabase environments.
-- All functions are private owner-connector helpers and are intentionally
-- unavailable to anon/authenticated clients.

create or replace function financecanvas_private.norm_text(p_value text)
returns text
language sql
immutable
security invoker
set search_path = pg_catalog
as $$
  select lower(regexp_replace(btrim(coalesce(p_value,'')), '\s+', ' ', 'g'));
$$;

revoke all on function financecanvas_private.norm_text(text)
from public, anon, authenticated;

create or replace function financecanvas_private.transaction_fingerprint(
  p_workspace_id uuid,
  p_account_id uuid,
  p_posted_date date,
  p_amount numeric,
  p_currency text,
  p_direction text,
  p_reference text,
  p_raw_description text
)
returns text
language sql
immutable
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
  select encode(
    extensions.digest(
      concat_ws(
        E'\x1f',
        p_workspace_id::text,
        p_account_id::text,
        p_posted_date::text,
        to_char(round(coalesce(p_amount,0),2),'FM999999999999999999999999999990.00'),
        upper(coalesce(nullif(btrim(p_currency),''),'INR')),
        financecanvas_private.norm_text(p_direction),
        financecanvas_private.norm_text(p_reference),
        financecanvas_private.norm_text(p_raw_description)
      ),
      'sha256'
    ),
    'hex'
  );
$$;

revoke all on function financecanvas_private.transaction_fingerprint(
  uuid,uuid,date,numeric,text,text,text,text
) from public, anon, authenticated;

create or replace function financecanvas_private.assert_import_payload_safe(p_payload jsonb)
returns void
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  v_text text := lower(coalesce(p_payload::text,''));
begin
  if v_text ~ '"(cvv|cvc|pin|upi_pin|otp|password|passcode|private_key|seed|mnemonic|recovery_phrase|api_key|access_token|refresh_token)"\s*:'
  then
    raise exception 'CRITICAL_SECRET_DETECTED: connector import payload contains a prohibited secret field';
  end if;

  if v_text ~ '"(aadhaar|aadhar|vid|pan|passport|tax_id|full_card_number|card_number|account_number)"\s*:'
  then
    raise exception 'HIGH_RISK_IDENTIFIER_DETECTED: connector import payload contains a prohibited identifier field';
  end if;

  if v_text ~ '[A-Z]{5}[0-9]{4}[A-Z]'
  then
    raise exception 'HIGH_RISK_IDENTIFIER_DETECTED: connector import payload appears to contain a PAN';
  end if;
end;
$$;

revoke all on function financecanvas_private.assert_import_payload_safe(jsonb)
from public, anon, authenticated;

create or replace function financecanvas_private.ensure_account(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_institution_name text,
  p_account_name text,
  p_account_type text,
  p_currency text,
  p_identifier_last4 text default null,
  p_credit_limit numeric default null
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  v_institution_id uuid;
  v_account public.accounts%rowtype;
  v_name text := btrim(coalesce(p_account_name,''));
  v_institution text := btrim(coalesce(p_institution_name,''));
  v_type text := lower(btrim(coalesce(p_account_type,'')));
  v_currency text := upper(btrim(coalesce(p_currency,'INR')));
  v_last4 text := nullif(regexp_replace(coalesce(p_identifier_last4,''),'[^0-9A-Za-z]','','g'),'');
  v_created boolean := false;
  v_differences jsonb := '{}'::jsonb;
begin
  if not exists (
    select 1 from public.workspaces w where w.id=p_workspace_id
  ) then
    raise exception 'WORKSPACE_NOT_FOUND';
  end if;

  if not exists (
    select 1 from public.profiles p
    where p.id=p_profile_id and p.workspace_id=p_workspace_id and p.deleted_at is null
  ) then
    raise exception 'PROFILE_NOT_IN_WORKSPACE';
  end if;

  if v_name='' then raise exception 'account name is required'; end if;
  if v_type not in ('bank','credit_card','wallet','cash','brokerage','loan','other') then
    raise exception 'invalid account type';
  end if;
  if v_currency !~ '^[A-Z]{3}$' then raise exception 'invalid currency'; end if;
  if v_last4 is not null and char_length(v_last4)>8 then
    raise exception 'identifier_last4 must be masked/last-four style';
  end if;

  if v_institution<>'' then
    select i.id into v_institution_id
    from public.institutions i
    where i.workspace_id=p_workspace_id
      and i.deleted_at is null
      and lower(i.name)=lower(v_institution)
    order by i.created_at
    limit 1;

    if v_institution_id is null then
      insert into public.institutions(workspace_id,name,institution_type)
      values(p_workspace_id,v_institution,'financial_institution')
      returning id into v_institution_id;
    end if;
  end if;

  select a.* into v_account
  from public.accounts a
  where a.workspace_id=p_workspace_id
    and a.deleted_at is null
    and a.account_type=v_type
    and (
      (v_last4 is not null and a.identifier_last4=v_last4)
      or
      (v_last4 is null and lower(a.name)=lower(v_name))
    )
    and (v_institution_id is null or a.institution_id=v_institution_id)
  order by a.created_at
  limit 1;

  if not found then
    insert into public.accounts(
      workspace_id,institution_id,name,account_type,currency,
      identifier_last4,credit_limit,metadata
    )
    values(
      p_workspace_id,v_institution_id,v_name,v_type,v_currency,
      v_last4,p_credit_limit,
      jsonb_build_object(
        'privacy_classification','private_financial',
        'identifier_masked',v_last4 is not null
      )
    )
    returning * into v_account;

    insert into public.account_owners(account_id,profile_id,ownership_percent,is_primary)
    values(v_account.id,p_profile_id,100,true)
    on conflict(account_id,profile_id) do nothing;

    insert into public.audit_log(
      workspace_id,actor_type,action,target_table,target_id,after_snapshot,metadata
    )
    values(
      p_workspace_id,'supabase_connector','connector_create_account','accounts',v_account.id,
      jsonb_build_object(
        'id',v_account.id,'name',v_account.name,'account_type',v_account.account_type,
        'currency',v_account.currency,'identifier_last4',v_account.identifier_last4
      ),
      jsonb_build_object('data_minimized',true,'connector_mode',true)
    );

    v_created := true;
  else
    if v_account.currency<>v_currency then
      v_differences := v_differences || jsonb_build_object(
        'currency',jsonb_build_object('existing',v_account.currency,'incoming',v_currency)
      );
    end if;

    if p_credit_limit is not null
       and v_account.credit_limit is distinct from p_credit_limit then
      v_differences := v_differences || jsonb_build_object(
        'credit_limit',jsonb_build_object('existing',v_account.credit_limit,'incoming',p_credit_limit)
      );
    end if;

    insert into public.account_owners(account_id,profile_id,ownership_percent,is_primary)
    values(v_account.id,p_profile_id,100,true)
    on conflict(account_id,profile_id) do nothing;
  end if;

  return jsonb_build_object(
    'account',jsonb_build_object(
      'id',v_account.id,
      'name',v_account.name,
      'account_type',v_account.account_type,
      'currency',v_account.currency,
      'identifier_last4',v_account.identifier_last4,
      'credit_limit',v_account.credit_limit,
      'institution_id',v_account.institution_id
    ),
    'created',v_created,
    'differences',v_differences,
    'confirmation_required_for_differences',v_differences<>'{}'::jsonb
  );
end;
$$;

revoke all on function financecanvas_private.ensure_account(
  uuid,uuid,text,text,text,text,text,numeric
) from public, anon, authenticated;

create or replace function financecanvas_private.preview_statement_import(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_account_id uuid,
  p_source_hash text,
  p_rows jsonb
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  r jsonb;
  v_client text;
  v_fingerprint text;
  v_existing jsonb;
  v_matches jsonb;
  v_results jsonb := '[]'::jsonb;
  v_existing_import jsonb;
  v_index integer := 0;
  v_date date;
  v_amount numeric;
  v_currency text;
  v_direction text;
  v_compare_text text;
begin
  perform financecanvas_private.assert_import_payload_safe(p_rows);

  if jsonb_typeof(p_rows)<>'array' then
    raise exception 'transactions must be an array';
  end if;

  if not exists(
    select 1 from public.profiles
    where id=p_profile_id and workspace_id=p_workspace_id and deleted_at is null
  ) then raise exception 'PROFILE_NOT_IN_WORKSPACE'; end if;

  if not exists(
    select 1 from public.accounts
    where id=p_account_id and workspace_id=p_workspace_id and deleted_at is null
  ) then raise exception 'ACCOUNT_NOT_IN_WORKSPACE'; end if;

  if nullif(btrim(coalesce(p_source_hash,'')),'') is not null then
    select jsonb_build_object(
      'id',i.id,'source_type',i.source_type,'original_filename',i.original_filename,
      'statement_start',i.statement_start,'statement_end',i.statement_end,
      'status',i.status,'record_count',i.record_count,'created_at',i.created_at
    )
    into v_existing_import
    from public.imports i
    where i.workspace_id=p_workspace_id
      and i.source_hash=p_source_hash
      and i.status in ('committed','completed')
      and i.deleted_at is null
    order by i.created_at
    limit 1;
  end if;

  if v_existing_import is not null then
    return jsonb_build_object(
      'duplicate_source_document',true,
      'existing_import',v_existing_import,
      'results','[]'::jsonb
    );
  end if;

  for r in select value from jsonb_array_elements(p_rows)
  loop
    v_index := v_index + 1;
    v_client := coalesce(nullif(r->>'client_id',''),'row-'||v_index::text);

    if nullif(r->>'posted_date','') is null
       or nullif(r->>'amount','') is null
       or nullif(r->>'direction','') is null then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'client_id',v_client,'status','needs_confirmation',
        'message','posted_date, amount and direction are required'
      ));
      continue;
    end if;

    v_date := (r->>'posted_date')::date;
    v_amount := (r->>'amount')::numeric;
    v_currency := upper(coalesce(nullif(btrim(r->>'currency'),''),'INR'));
    v_direction := lower(btrim(r->>'direction'));

    if v_amount<0 or v_direction not in ('debit','credit') then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'client_id',v_client,'status','needs_confirmation',
        'message','amount must be non-negative and direction must be debit/credit'
      ));
      continue;
    end if;

    v_fingerprint := financecanvas_private.transaction_fingerprint(
      p_workspace_id,p_account_id,v_date,v_amount,v_currency,v_direction,
      r->>'transaction_reference',r->>'raw_description'
    );

    select jsonb_build_object(
      'id',t.id,'posted_date',t.posted_date,'amount',t.amount,'currency',t.currency,
      'direction',t.direction,'merchant_normalized',t.merchant_normalized,
      'raw_description',t.raw_description,'transaction_reference',t.transaction_reference,
      'category',t.category,'subcategory',t.subcategory,'profile_id',t.profile_id,
      'account_id',t.account_id
    )
    into v_existing
    from public.transactions t
    where t.workspace_id=p_workspace_id
      and t.account_id=p_account_id
      and t.deleted_at is null
      and t.posted_date=v_date
      and t.amount=v_amount
      and upper(t.currency)=v_currency
      and lower(t.direction)=v_direction
      and financecanvas_private.norm_text(t.transaction_reference)
          = financecanvas_private.norm_text(r->>'transaction_reference')
      and financecanvas_private.norm_text(t.raw_description)
          = financecanvas_private.norm_text(r->>'raw_description')
    order by t.created_at
    limit 1;

    if v_existing is not null then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'client_id',v_client,'status','exact_duplicate',
        'base_fingerprint',v_fingerprint,'existing',v_existing
      ));
      v_existing := null;
      continue;
    end if;

    v_compare_text := financecanvas_private.norm_text(
      coalesce(nullif(r->>'merchant_normalized',''),r->>'raw_description','')
    );

    select coalesce(jsonb_agg(x.payload),'[]'::jsonb)
    into v_matches
    from (
      select jsonb_build_object(
        'id',t.id,'posted_date',t.posted_date,'amount',t.amount,'currency',t.currency,
        'direction',t.direction,'merchant_normalized',t.merchant_normalized,
        'raw_description',t.raw_description,'transaction_reference',t.transaction_reference,
        'category',t.category,'subcategory',t.subcategory,'profile_id',t.profile_id,
        'account_id',t.account_id,
        'similarity',extensions.similarity(
          financecanvas_private.norm_text(coalesce(t.merchant_normalized,t.raw_description,'')),
          v_compare_text
        )
      ) as payload
      from public.transactions t
      where t.workspace_id=p_workspace_id
        and t.account_id=p_account_id
        and t.deleted_at is null
        and t.amount=v_amount
        and upper(t.currency)=v_currency
        and lower(t.direction)=v_direction
        and t.posted_date between (v_date-3) and (v_date+3)
        and extensions.similarity(
          financecanvas_private.norm_text(coalesce(t.merchant_normalized,t.raw_description,'')),
          v_compare_text
        )>=0.5
      order by abs(t.posted_date-v_date),t.created_at
      limit 5
    ) x;

    if jsonb_array_length(v_matches)>0 then
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'client_id',v_client,'status','near_duplicate',
        'base_fingerprint',v_fingerprint,'matches',v_matches
      ));
    else
      v_results := v_results || jsonb_build_array(jsonb_build_object(
        'client_id',v_client,'status','ready','base_fingerprint',v_fingerprint
      ));
    end if;
  end loop;

  return jsonb_build_object(
    'duplicate_source_document',false,
    'results',v_results
  );
end;
$$;

revoke all on function financecanvas_private.preview_statement_import(
  uuid,uuid,uuid,text,jsonb
) from public, anon, authenticated;

drop index if exists public.committed_import_hash_unique;
create unique index committed_import_hash_unique
on public.imports(workspace_id,source_hash)
where source_hash is not null
  and status in ('committed','completed')
  and deleted_at is null;

create or replace function financecanvas_private.commit_statement_import(
  p_workspace_id uuid,
  p_profile_id uuid,
  p_account_id uuid,
  p_import jsonb,
  p_rows jsonb,
  p_duplicate_resolutions jsonb default '[]'::jsonb,
  p_final_confirmation boolean default false
)
returns jsonb
language plpgsql
security invoker
set search_path = pg_catalog, public, financecanvas_private
as $$
declare
  r jsonb;
  v_resolution jsonb;
  v_client text;
  v_fingerprint text;
  v_final_fingerprint text;
  v_existing public.transactions%rowtype;
  v_near public.transactions%rowtype;
  v_prepared jsonb := '[]'::jsonb;
  v_prepared_with_import jsonb := '[]'::jsonb;
  v_reviews jsonb := '[]'::jsonb;
  v_skipped jsonb := '[]'::jsonb;
  v_conflicts jsonb := '[]'::jsonb;
  v_index integer := 0;
  v_date date;
  v_amount numeric;
  v_currency text;
  v_direction text;
  v_compare_text text;
  v_duplicate_of uuid;
  v_override_reason text;
  v_source_hash text := nullif(btrim(coalesce(p_import->>'source_hash','')),'');
  v_import_id uuid;
  v_batch jsonb;
  v_account_type text;
  v_existing_import public.imports%rowtype;
begin
  if p_final_confirmation is not true then
    return jsonb_build_object(
      'atomic_commit',false,
      'confirmation_required',true,
      'message','Final user confirmation is required before commit.'
    );
  end if;

  perform financecanvas_private.assert_import_payload_safe(p_import);
  perform financecanvas_private.assert_import_payload_safe(p_rows);

  if jsonb_typeof(p_rows)<>'array'
     or jsonb_typeof(coalesce(p_duplicate_resolutions,'[]'::jsonb))<>'array' then
    raise exception 'transactions/resolutions must be arrays';
  end if;

  if not exists(
    select 1 from public.profiles
    where id=p_profile_id and workspace_id=p_workspace_id and deleted_at is null
  ) then raise exception 'PROFILE_NOT_IN_WORKSPACE'; end if;

  select a.account_type into v_account_type
  from public.accounts a
  where a.id=p_account_id and a.workspace_id=p_workspace_id and a.deleted_at is null;

  if v_account_type is null then raise exception 'ACCOUNT_NOT_IN_WORKSPACE'; end if;

  if v_source_hash is not null then
    select i.* into v_existing_import
    from public.imports i
    where i.workspace_id=p_workspace_id
      and i.source_hash=v_source_hash
      and i.status in ('committed','completed')
      and i.deleted_at is null
    order by i.created_at
    limit 1;

    if found then
      return jsonb_build_object(
        'atomic_commit',false,
        'duplicate_source_document',true,
        'existing_import',jsonb_build_object(
          'id',v_existing_import.id,
          'original_filename',v_existing_import.original_filename,
          'statement_start',v_existing_import.statement_start,
          'statement_end',v_existing_import.statement_end,
          'status',v_existing_import.status,
          'record_count',v_existing_import.record_count
        )
      );
    end if;
  end if;

  for r in select value from jsonb_array_elements(p_rows)
  loop
    v_index := v_index + 1;
    v_client := coalesce(nullif(r->>'client_id',''),'row-'||v_index::text);
    v_resolution := null;
    v_duplicate_of := null;
    v_override_reason := null;

    if nullif(r->>'posted_date','') is null
       or nullif(r->>'amount','') is null
       or nullif(r->>'direction','') is null then
      v_conflicts := v_conflicts || jsonb_build_array(jsonb_build_object(
        'client_id',v_client,'type','invalid',
        'message','posted_date, amount and direction are required'
      ));
      continue;
    end if;

    v_date := (r->>'posted_date')::date;
    v_amount := (r->>'amount')::numeric;
    v_currency := upper(coalesce(nullif(btrim(r->>'currency'),''),'INR'));
    v_direction := lower(btrim(r->>'direction'));

    if v_amount<0 or v_direction not in ('debit','credit') then
      v_conflicts := v_conflicts || jsonb_build_array(jsonb_build_object(
        'client_id',v_client,'type','invalid',
        'message','amount must be non-negative and direction must be debit/credit'
      ));
      continue;
    end if;

    v_fingerprint := financecanvas_private.transaction_fingerprint(
      p_workspace_id,p_account_id,v_date,v_amount,v_currency,v_direction,
      r->>'transaction_reference',r->>'raw_description'
    );
    v_final_fingerprint := v_fingerprint;

    select t.* into v_existing
    from public.transactions t
    where t.workspace_id=p_workspace_id
      and t.account_id=p_account_id
      and t.deleted_at is null
      and t.posted_date=v_date
      and t.amount=v_amount
      and upper(t.currency)=v_currency
      and lower(t.direction)=v_direction
      and financecanvas_private.norm_text(t.transaction_reference)
          = financecanvas_private.norm_text(r->>'transaction_reference')
      and financecanvas_private.norm_text(t.raw_description)
          = financecanvas_private.norm_text(r->>'raw_description')
    order by t.created_at
    limit 1;

    if found then
      select value into v_resolution
      from jsonb_array_elements(coalesce(p_duplicate_resolutions,'[]'::jsonb))
      where value->>'client_id'=v_client
      limit 1;

      if v_resolution is null then
        v_conflicts := v_conflicts || jsonb_build_array(jsonb_build_object(
          'client_id',v_client,'type','exact','existing_transaction_id',v_existing.id
        ));
        continue;
      end if;

      if coalesce(v_resolution->>'decision','') in ('skip','keep_existing','cancel') then
        v_reviews := v_reviews || jsonb_build_array(jsonb_build_object(
          'existing_transaction_id',v_existing.id,
          'incoming_fingerprint',v_fingerprint,
          'duplicate_type','exact',
          'decision',case when v_resolution->>'decision'='cancel' then 'cancel' else 'skip' end,
          'reason',nullif(v_resolution->>'reason',''),
          'incoming_snapshot',jsonb_build_object(
            'posted_date',v_date,'amount',v_amount,'currency',v_currency,
            'direction',v_direction,'merchant_normalized',r->>'merchant_normalized'
          ),
          'difference','{}'::jsonb
        ));
        v_skipped := v_skipped || jsonb_build_array(
          jsonb_build_object('client_id',v_client,'reason',v_resolution->>'decision')
        );
        continue;
      end if;

      if v_resolution->>'decision' <> 'add_separate'
         or nullif(btrim(coalesce(v_resolution->>'reason','')),'') is null then
        v_conflicts := v_conflicts || jsonb_build_array(jsonb_build_object(
          'client_id',v_client,'type','exact',
          'message','add_separate requires a non-empty reason'
        ));
        continue;
      end if;

      v_duplicate_of := v_existing.id;
      v_override_reason := btrim(v_resolution->>'reason');
      v_final_fingerprint := encode(
        extensions.digest(v_fingerprint||'|override|'||v_override_reason||'|'||gen_random_uuid()::text,'sha256'),
        'hex'
      );

      v_reviews := v_reviews || jsonb_build_array(jsonb_build_object(
        'existing_transaction_id',v_existing.id,
        'incoming_fingerprint',v_fingerprint,
        'duplicate_type','exact','decision','add_separate',
        'reason',v_override_reason,
        'incoming_snapshot',jsonb_build_object(
          'posted_date',v_date,'amount',v_amount,'currency',v_currency,
          'direction',v_direction,'merchant_normalized',r->>'merchant_normalized'
        ),
        'difference','{}'::jsonb
      ));
    else
      v_compare_text := financecanvas_private.norm_text(
        coalesce(nullif(r->>'merchant_normalized',''),r->>'raw_description','')
      );

      select t.* into v_near
      from public.transactions t
      where t.workspace_id=p_workspace_id
        and t.account_id=p_account_id
        and t.deleted_at is null
        and t.amount=v_amount
        and upper(t.currency)=v_currency
        and lower(t.direction)=v_direction
        and t.posted_date between (v_date-3) and (v_date+3)
        and extensions.similarity(
          financecanvas_private.norm_text(coalesce(t.merchant_normalized,t.raw_description,'')),
          v_compare_text
        )>=0.5
      order by abs(t.posted_date-v_date),t.created_at
      limit 1;

      if found then
        select value into v_resolution
        from jsonb_array_elements(coalesce(p_duplicate_resolutions,'[]'::jsonb))
        where value->>'client_id'=v_client
        limit 1;

        if v_resolution is null then
          v_conflicts := v_conflicts || jsonb_build_array(jsonb_build_object(
            'client_id',v_client,'type','near','existing_transaction_id',v_near.id
          ));
          continue;
        end if;

        if coalesce(v_resolution->>'decision','') in ('skip','keep_existing','cancel') then
          v_reviews := v_reviews || jsonb_build_array(jsonb_build_object(
            'existing_transaction_id',v_near.id,
            'incoming_fingerprint',v_fingerprint,
            'duplicate_type','near',
            'decision',case when v_resolution->>'decision'='cancel' then 'cancel' else 'keep_existing' end,
            'reason',nullif(v_resolution->>'reason',''),
            'incoming_snapshot',jsonb_build_object(
              'posted_date',v_date,'amount',v_amount,'currency',v_currency,
              'direction',v_direction,'merchant_normalized',r->>'merchant_normalized'
            ),
            'difference',jsonb_build_object(
              'posted_date',jsonb_build_object('existing',v_near.posted_date,'incoming',v_date),
              'merchant_normalized',jsonb_build_object(
                'existing',v_near.merchant_normalized,'incoming',r->>'merchant_normalized'
              )
            )
          ));
          v_skipped := v_skipped || jsonb_build_array(
            jsonb_build_object('client_id',v_client,'reason',v_resolution->>'decision')
          );
          continue;
        end if;

        if v_resolution->>'decision'='update_existing' then
          v_conflicts := v_conflicts || jsonb_build_array(jsonb_build_object(
            'client_id',v_client,'type','near',
            'message','Use the two-step edit workflow to update the existing transaction.',
            'existing_transaction_id',v_near.id
          ));
          continue;
        end if;

        if v_resolution->>'decision' <> 'add_separate'
           or nullif(btrim(coalesce(v_resolution->>'reason','')),'') is null then
          v_conflicts := v_conflicts || jsonb_build_array(jsonb_build_object(
            'client_id',v_client,'type','near',
            'message','add_separate requires a non-empty reason'
          ));
          continue;
        end if;

        v_duplicate_of := v_near.id;
        v_override_reason := btrim(v_resolution->>'reason');
        v_final_fingerprint := encode(
          extensions.digest(v_fingerprint||'|override|'||v_override_reason||'|'||gen_random_uuid()::text,'sha256'),
          'hex'
        );

        v_reviews := v_reviews || jsonb_build_array(jsonb_build_object(
          'existing_transaction_id',v_near.id,
          'incoming_fingerprint',v_fingerprint,
          'duplicate_type','near','decision','add_separate',
          'reason',v_override_reason,
          'incoming_snapshot',jsonb_build_object(
            'posted_date',v_date,'amount',v_amount,'currency',v_currency,
            'direction',v_direction,'merchant_normalized',r->>'merchant_normalized'
          ),
          'difference',jsonb_build_object(
            'posted_date',jsonb_build_object('existing',v_near.posted_date,'incoming',v_date),
            'merchant_normalized',jsonb_build_object(
              'existing',v_near.merchant_normalized,'incoming',r->>'merchant_normalized'
            )
          )
        ));
      end if;
    end if;

    v_prepared := v_prepared || jsonb_build_array(jsonb_build_object(
      'workspace_id',p_workspace_id,
      'profile_id',p_profile_id,
      'account_id',p_account_id,
      'posted_date',v_date,
      'transaction_date',nullif(r->>'transaction_date',''),
      'amount',v_amount,
      'currency',v_currency,
      'direction',v_direction,
      'raw_description',r->>'raw_description',
      'merchant_normalized',r->>'merchant_normalized',
      'transaction_reference',r->>'transaction_reference',
      'category',r->>'category',
      'subcategory',r->>'subcategory',
      'purpose',r->>'purpose',
      'confidence',r->>'confidence',
      'confirmation_status',coalesce(nullif(r->>'confirmation_status',''),'confirmed'),
      'balance_after',r->>'balance_after',
      'source_sequence',r->>'source_sequence',
      'raw_values',coalesce(r->'raw_values','{}'::jsonb),
      'normalized_values',coalesce(r->'normalized_values','{}'::jsonb),
      'base_fingerprint',v_fingerprint,
      'fingerprint',v_final_fingerprint,
      'duplicate_of_transaction_id',v_duplicate_of,
      'duplicate_override_reason',v_override_reason,
      'duplicate_override_at',case when v_override_reason is null then null else now() end
    ));
  end loop;

  if jsonb_array_length(v_conflicts)>0 then
    return jsonb_build_object(
      'atomic_commit',false,
      'inserted','[]'::jsonb,
      'skipped',v_skipped,
      'conflicts',v_conflicts
    );
  end if;

  insert into public.imports(
    workspace_id,profile_id,account_id,source_type,original_filename,source_hash,
    statement_start,statement_end,status,reconciliation_status,reconciliation_difference,
    detected_document_type,detected_issuer,confidence,metadata
  )
  values(
    p_workspace_id,p_profile_id,p_account_id,
    coalesce(nullif(p_import->>'source_type',''),'document'),
    nullif(p_import->>'original_filename',''),
    v_source_hash,
    nullif(p_import->>'statement_start','')::date,
    nullif(p_import->>'statement_end','')::date,
    'confirmed',
    nullif(p_import->>'reconciliation_status',''),
    nullif(p_import->>'reconciliation_difference','')::numeric,
    nullif(p_import->>'detected_document_type',''),
    nullif(p_import->>'detected_issuer',''),
    nullif(p_import->>'confidence','')::numeric,
    coalesce(p_import->'metadata','{}'::jsonb)
      || jsonb_build_object(
        'privacy_classification','private_financial',
        'source_document_stored',false,
        'identifiers_masked',true,
        'connector_mode',true
      )
  )
  returning id into v_import_id;

  select coalesce(
    jsonb_agg(
      value || jsonb_build_object('import_id',v_import_id)
    ),
    '[]'::jsonb
  )
  into v_prepared_with_import
  from jsonb_array_elements(v_prepared);

  v_batch := public.financecanvas_commit_transaction_batch(
    p_workspace_id,v_prepared_with_import,v_reviews
  );

  if v_account_type='credit_card'
     and nullif(p_import->>'statement_end','') is not null then
    insert into public.credit_card_statements(
      workspace_id,account_id,import_id,statement_start,statement_end,due_date,
      currency,statement_balance,minimum_due,total_due,fees_total,interest_total,
      payment_status,metadata
    )
    values(
      p_workspace_id,p_account_id,v_import_id,
      nullif(p_import->>'statement_start','')::date,
      (p_import->>'statement_end')::date,
      nullif(p_import->>'due_date','')::date,
      upper(coalesce(nullif(p_import->>'currency',''),'INR')),
      nullif(p_import->>'statement_balance','')::numeric,
      nullif(p_import->>'minimum_due','')::numeric,
      nullif(p_import->>'total_due','')::numeric,
      nullif(p_import->>'fees_total','')::numeric,
      nullif(p_import->>'interest_total','')::numeric,
      coalesce(nullif(p_import->>'payment_status',''),'unknown'),
      jsonb_build_object(
        'privacy_classification','private_financial',
        'source_document_stored',false
      )
    )
    on conflict(account_id,statement_end) do nothing;
  end if;

  update public.imports
  set status='completed',
      record_count=(select count(*) from public.transactions where import_id=v_import_id and deleted_at is null),
      committed_at=coalesce(committed_at,now()),
      completed_at=now(),
      updated_at=now()
  where id=v_import_id;

  return jsonb_build_object(
    'atomic_commit',true,
    'import_id',v_import_id,
    'inserted_count',coalesce((v_batch->>'count')::integer,0),
    'inserted_ids',coalesce(v_batch->'inserted_ids','[]'::jsonb),
    'skipped',v_skipped,
    'conflicts','[]'::jsonb,
    'source_document_stored',false
  );
exception
  when unique_violation then
    return jsonb_build_object(
      'atomic_commit',false,
      'error','DUPLICATE_SOURCE_OR_TRANSACTION',
      'message','A concurrent duplicate was detected. Re-run preview before committing.'
    );
end;
$$;

revoke all on function financecanvas_private.commit_statement_import(
  uuid,uuid,uuid,jsonb,jsonb,jsonb,boolean
) from public, anon, authenticated;
