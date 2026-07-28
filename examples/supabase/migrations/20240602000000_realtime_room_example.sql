-- Schema for the "realtime: Postgres Changes, Broadcast and Presence" example.
--
-- A single `messages` table backs the room's chat log. The example streams
-- inserts and deletes on this table to every connected client through Postgres
-- Changes. Broadcast (typing pings) and Presence (the online roster) are
-- transient and need no tables of their own.

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  username text not null,
  content text not null,
  created_at timestamptz not null default now()
);

create index messages_created_at_idx on public.messages (created_at);

-- Stream row changes on this table to subscribed realtime clients by adding it
-- to the realtime publication. Without this, Postgres Changes emits nothing.
alter publication supabase_realtime add table public.messages;

-- Include the full previous row in delete (and update) change payloads. By
-- default only the primary key is sent on delete; the example only needs the
-- id, but this keeps the payload complete.
alter table public.messages replica identity full;

-- The example runs unauthenticated with the publishable (anon) key. Enable row
-- level security and add permissive policies so anyone can read and post to the
-- shared room. A real app would scope these to the signed in user instead.
--
-- Realtime also checks the select policy before streaming a change to a role, so
-- "anyone can read" is what lets the anon key receive Postgres Changes here.
alter table public.messages enable row level security;

create policy "Anyone can read messages"
  on public.messages for select using (true);

create policy "Anyone can post messages"
  on public.messages for insert with check (true);

create policy "Anyone can delete messages"
  on public.messages for delete using (true);

-- Row level security decides which rows a role may touch, but the role still
-- needs table privileges. Grant the publishable (anon) key read, insert and
-- delete on messages so the demo works without signing in.
grant select, insert, delete on public.messages to anon, authenticated;
