-- Test data loaded after migrations during `supabase db reset` / `supabase start`.

-- ---------------------------------------------------------------------------
-- postgrest_client dummy data (ported from infra/postgrest/db/01-dummy-data.sql)
-- ---------------------------------------------------------------------------
insert into
    public.users (username, status, age_range, catchphrase, interests)
values
    ('supabot', 'ONLINE', '[1,2)'::int4range, 'fat cat'::tsvector, '{"basketball", "baseball"}'),
    ('kiwicopple', 'OFFLINE', '[25,35)'::int4range, 'cat bat'::tsvector, '{"football"}'),
    ('awailas', 'ONLINE', '[25,35)'::int4range, 'bat rat'::tsvector, '{"tennis", "basketball"}'),
    ('dragarcia', 'ONLINE', '[20,30)'::int4range, 'rat fat'::tsvector, null);

insert into
    public.channels (slug)
values
    ('public'),
    ('random');

insert into
    public.messages (message, channel_id, username, inserted_at)
values
    ('Hello World 👋', 1, 'supabot', '2021-06-25T04:28:21.598Z'),
    ('Perfection is attained, not when there is nothing more to add, but when there is nothing left to take away.', 2, 'supabot', '2021-06-29T04:28:21.598Z'),
    ('Supabase Launch Week is on fire', 1, 'supabot', '2021-06-20T04:28:21.598Z');

insert into
    personal.users (username, status, age_range)
values
    ('supabot', 'ONLINE', '[1,2)'::int4range),
    ('kiwicopple', 'OFFLINE', '[25,35)'::int4range),
    ('awailas', 'ONLINE', '[25,35)'::int4range),
    ('dragarcia', 'ONLINE', '[20,30)'::int4range),
    ('leroyjenkins', 'ONLINE', '[20,40)'::int4range);

insert into
    public."TestTable" (slug)
values
    ('public'),
    ('random');

insert into
    public.reactions (emoji, message_id, created_at)
values
    ('😀', 1, '2021-06-25T04:28:21.598Z'),
    ('👋', 1, '2021-06-29T04:28:21.598Z'),
    ('😂', 1, '2021-06-20T04:28:21.598Z'),
    ('😂', 2, '2021-06-29T04:28:21.598Z'),
    ('😂', 2, '2021-06-22T04:28:21.598Z');

insert into public.addresses (username, location)
values ('supabot', 'SRID=4326;POINT(-71.10044 42.373695)');

-- ---------------------------------------------------------------------------
-- storage_client dummy data (ported from infra/storage_client/postgres/dummy-data.sql)
-- The storage tests authenticate with the service_role key, which bypasses RLS,
-- so the previous per-user policies are no longer needed; only the buckets and
-- objects the tests read are seeded. The owners are seeded as auth users so the
-- owner references resolve.
-- ---------------------------------------------------------------------------
-- The token columns are set to empty strings (not NULL) because gotrue scans them
-- as plain strings; NULLs there break admin user listing.
insert into auth.users (
    instance_id, id, aud, role, email, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change
)
values
    ('00000000-0000-0000-0000-000000000000', '317eadce-631a-4429-a0bb-f19a7a517b4a', 'authenticated', 'authenticated', 'inian+user2@supabase.io', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', '4d56e902-f0a0-4662-8448-a4d9e643c142', 'authenticated', 'authenticated', 'inian+user1@supabase.io', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', 'd8c7bce9-cfeb-497b-bd61-e66ce2cbdaa2', 'authenticated', 'authenticated', 'inian+admin@supabase.io', now(), now(), '', '', '', '')
on conflict (id) do nothing;

insert into storage.buckets (id, name, owner, created_at, updated_at)
values
    ('bucket2', 'bucket2', '4d56e902-f0a0-4662-8448-a4d9e643c142', '2021-02-17 04:43:32.770206+00', '2021-02-17 04:43:32.770206+00'),
    ('bucket3', 'bucket3', '4d56e902-f0a0-4662-8448-a4d9e643c142', '2021-02-17 04:43:32.770206+00', '2021-02-17 04:43:32.770206+00'),
    ('bucket4', 'bucket4', '317eadce-631a-4429-a0bb-f19a7a517b4a', '2021-02-25 09:23:01.58385+00', '2021-02-25 09:23:01.58385+00'),
    ('bucket5', 'bucket5', '317eadce-631a-4429-a0bb-f19a7a517b4a', '2021-02-27 03:04:25.6386+00', '2021-02-27 03:04:25.6386+00');

insert into storage.objects (id, bucket_id, name, owner, created_at, updated_at, last_accessed_at, metadata)
values
    ('03e458f9-892f-4db2-8cb9-d3401a689e25', 'bucket2', 'public/sadcat-upload23.png', '317eadce-631a-4429-a0bb-f19a7a517b4a', '2021-03-04 08:26:08.553748+00', '2021-03-04 08:26:08.553748+00', '2021-03-04 08:26:08.553748+00', '{"mimetype": "image/svg+xml", "size": 1234}'),
    ('070825af-a11d-44fe-9f1d-abdc76f686f2', 'bucket2', 'public/sadcat-upload.png', '317eadce-631a-4429-a0bb-f19a7a517b4a', '2021-03-02 16:31:11.115996+00', '2021-03-02 16:31:11.115996+00', '2021-03-02 16:31:11.115996+00', '{"mimetype": "image/png", "size": 1234}'),
    ('0cac5609-11e1-4f21-b486-d0eeb60909f6', 'bucket2', 'curlimage.jpg', 'd8c7bce9-cfeb-497b-bd61-e66ce2cbdaa2', '2021-02-23 11:05:16.625075+00', '2021-02-23 11:05:16.625075+00', '2021-02-23 11:05:16.625075+00', '{"size": 1234}'),
    ('147c6795-94d5-4008-9d81-f7ba3b4f8a9f', 'bucket2', 'folder/only_uid.jpg', 'd8c7bce9-cfeb-497b-bd61-e66ce2cbdaa2', '2021-02-17 10:36:01.504227+00', '2021-02-17 11:03:03.049618+00', '2021-02-17 10:36:01.504227+00', '{"size": 1234}'),
    ('65a3aa9c-0ff2-4adc-85d0-eab673c27443', 'bucket2', 'authenticated/casestudy.png', 'd8c7bce9-cfeb-497b-bd61-e66ce2cbdaa2', '2021-02-17 10:42:19.366559+00', '2021-02-17 11:03:30.025116+00', '2021-02-17 10:42:19.366559+00', '{"size": 1234}');
