-- Restored from deployed migration 20261002074704 (financecanvas_v014_database_first_analysis).

alter table public.imports
  add column if not exists analysis_ready boolean not null default false,
  add column if not exists analysis_missing_fields text[] not null default '{}'::text[],
  add column if not exists analysis_ready_at timestamptz;

comment on column public.imports.analysis_ready is
  'True only when enough structured data has been retained in FinanceCanvas to perform the intended analysis without rereading the source document.';
comment on column public.imports.analysis_missing_fields is
  'Structured fields that were not retained and materially limit analysis for this import.';
comment on column public.imports.analysis_ready_at is
  'When the import first became self-sufficient for database-only analysis.';

update public.imports i
set analysis_ready = case
      when exists (
        select 1 from public.transactions t
        where t.import_id=i.id and t.deleted_at is null
      ) then not exists (
        select 1 from public.transactions t
        where t.import_id=i.id and t.deleted_at is null
          and nullif(btrim(t.raw_description),'') is null
      )
      when exists (
        select 1 from public.import_entities ie
        where ie.import_id=i.id
      ) then true
      else false
    end,
    analysis_missing_fields = case
      when exists (
        select 1 from public.transactions t
        where t.import_id=i.id and t.deleted_at is null
          and nullif(btrim(t.raw_description),'') is null
      ) then array['raw_description']::text[]
      else '{}'::text[]
    end,
    analysis_ready_at = case
      when (
        (
          exists (select 1 from public.transactions t where t.import_id=i.id and t.deleted_at is null)
          and not exists (
            select 1 from public.transactions t
            where t.import_id=i.id and t.deleted_at is null
              and nullif(btrim(t.raw_description),'') is null
          )
        )
        or exists (select 1 from public.import_entities ie where ie.import_id=i.id)
      ) then coalesce(i.completed_at,i.committed_at,i.updated_at,now())
      else null
    end;

update public.financecanvas_schema
set schema_version='0.1.4', applied_at=now()
where singleton=true;
