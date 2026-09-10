begin;

create extension if not exists pgtap with schema extensions;

select plan(2);

select ok(
  not exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind = 'r'
      and c.relname not like 'spatial_ref_sys'
      and c.relrowsecurity = false
  ),
  'All public application tables have RLS enabled'
);

select ok(
  not exists (
    select 1
    from information_schema.role_table_grants g
    where g.table_schema = 'public'
      and g.table_name = 'admin_audit_logs'
      and g.grantee in ('anon', 'authenticated')
  ),
  'admin_audit_logs is not granted to anon/authenticated'
);

select * from finish();
rollback;
