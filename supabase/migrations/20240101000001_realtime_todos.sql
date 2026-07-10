-- Table used to exercise postgres_changes in the realtime_client integration tests.
-- Ported from the former infra/realtime_client/db/00-schema.sql (the roles and
-- schemas it created by hand are already provided by the Supabase CLI stack).
create table if not exists public.todos (
  id bigint generated always as identity primary key,
  task text,
  is_complete boolean not null default false,
  details jsonb default '{}'::jsonb,
  inserted_at timestamptz not null default now()
);

-- REPLICA IDENTITY FULL so that UPDATE and DELETE events include the previous row.
alter table public.todos replica identity full;

grant all on table public.todos to anon, authenticated, service_role;

-- Stream changes on the table the realtime tests subscribe to.
alter publication supabase_realtime add table public.todos;
