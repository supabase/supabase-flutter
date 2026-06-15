-- The bare supabase/postgres image does not create the standard Supabase roles
-- when started from an empty volume (they live in image subdirectory scripts
-- that the default entrypoint skips), so create the ones the Realtime server and
-- its migrations expect. Mirrors infra/storage_client/postgres/00-initial-schema.sql.

-- Superuser that the Realtime server connects as.
do $$
begin
  if not exists (select from pg_roles where rolname = 'supabase_admin') then
    create role supabase_admin
      login superuser createdb createrole replication bypassrls
      password 'postgres';
  end if;
end $$;
alter role supabase_admin set search_path to public, extensions;

-- API roles. The Realtime tenant migrations grant privileges to these, so they
-- must exist before the server runs its migrations.
do $$
begin
  if not exists (select from pg_roles where rolname = 'anon') then
    create role anon nologin noinherit;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin noinherit;
  end if;
  if not exists (select from pg_roles where rolname = 'service_role') then
    create role service_role nologin noinherit bypassrls;
  end if;
  if not exists (select from pg_roles where rolname = 'authenticator') then
    create role authenticator login noinherit password 'postgres';
  end if;
end $$;

grant anon to authenticator;
grant authenticated to authenticator;
grant service_role to authenticator;
grant supabase_admin to authenticator;

-- Schemas referenced by the Realtime migrations.
create schema if not exists extensions;
create extension if not exists "uuid-ossp" with schema extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists auth authorization supabase_admin;
grant usage on schema extensions to anon, authenticated, service_role;
grant usage on schema auth to anon, authenticated, service_role;

-- Schema used by the Realtime server to store its own metadata. The server runs
-- its migrations into this schema on startup (DB_AFTER_CONNECT_QUERY sets the
-- search_path to _realtime).
create schema if not exists _realtime authorization supabase_admin;

-- Table used to exercise postgres_changes in the integration tests.
create table if not exists public.todos (
  id bigint generated always as identity primary key,
  task text,
  is_complete boolean not null default false,
  details jsonb default '{}'::jsonb,
  inserted_at timestamptz not null default now()
);

-- REPLICA IDENTITY FULL so that UPDATE and DELETE events include the previous
-- row in the old record.
alter table public.todos replica identity full;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.todos to anon, authenticated, service_role;

-- Publication that the Realtime server streams changes from.
drop publication if exists supabase_realtime;
create publication supabase_realtime for table public.todos;
