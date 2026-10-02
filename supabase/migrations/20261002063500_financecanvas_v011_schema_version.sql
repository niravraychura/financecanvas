update public.financecanvas_schema
set schema_version='0.1.1', applied_at=now()
where singleton=true;
