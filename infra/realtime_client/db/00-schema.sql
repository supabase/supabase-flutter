-- Schema used by the Realtime server to store its own metadata. The server
-- runs its migrations into this schema on startup (DB_AFTER_CONNECT_QUERY sets
-- the search_path to _realtime).
create schema if not exists _realtime;
alter schema _realtime owner to supabase_admin;

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

-- Grant the API roles access so the anon JWT used in the tests can read changes.
grant usage on schema public to anon, authenticated, service_role;
grant all on table public.todos to anon, authenticated, service_role;

-- Publication that the Realtime server streams changes from.
drop publication if exists supabase_realtime;
create publication supabase_realtime for table public.todos;
