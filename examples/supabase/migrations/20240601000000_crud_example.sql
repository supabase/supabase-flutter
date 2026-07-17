-- Schema for the "database CRUD with PostgREST" example.
--
-- Two related tables (projects 1:N tasks) so the example can show selects with
-- filters and ordering, inserts, updates, deletes and a join from a task to its
-- project.

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects (id) on delete cascade,
  title text not null,
  is_complete boolean not null default false,
  priority int not null default 1,
  created_at timestamptz not null default now()
);

create index tasks_project_id_idx on public.tasks (project_id);

-- The example runs unauthenticated with the publishable (anon) key. Enable row
-- level security and add permissive policies so the demo can read and write
-- without signing in. A real app would scope these policies to the signed in
-- user instead.
alter table public.projects enable row level security;
alter table public.tasks enable row level security;

create policy "Anyone can read projects"
  on public.projects for select using (true);

create policy "Anyone can manage tasks"
  on public.tasks for all using (true) with check (true);

-- Row level security decides which rows a role may touch, but the role still
-- needs table privileges. Grant the publishable (anon) key read access to
-- projects and full access to tasks so the demo works without signing in.
grant select on public.projects to anon, authenticated;
grant all on public.tasks to anon, authenticated;
