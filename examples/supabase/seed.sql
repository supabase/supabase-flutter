-- Sample data for the database CRUD example. Runs when the local stack is first
-- created (`supabase start`) or reset (`supabase db reset`).

insert into public.projects (id, name) values
  ('00000000-0000-0000-0000-000000000001', 'Website redesign'),
  ('00000000-0000-0000-0000-000000000002', 'Mobile app'),
  ('00000000-0000-0000-0000-000000000003', 'Personal');

insert into public.tasks (project_id, title, is_complete, priority) values
  ('00000000-0000-0000-0000-000000000001', 'Draft the landing page copy', false, 3),
  ('00000000-0000-0000-0000-000000000001', 'Pick a color palette', true, 1),
  ('00000000-0000-0000-0000-000000000002', 'Set up push notifications', false, 2),
  ('00000000-0000-0000-0000-000000000002', 'Fix login on Android', false, 3),
  ('00000000-0000-0000-0000-000000000003', 'Book flights', false, 2),
  ('00000000-0000-0000-0000-000000000003', 'Water the plants', true, 1);

-- Sample data for the realtime room example.

insert into public.messages (username, content) values
  ('supabase', 'Welcome to the room! Open this example in a second window to chat live.'),
  ('supabase', 'Messages stream over Postgres Changes, typing pings over Broadcast and the roster over Presence.');
