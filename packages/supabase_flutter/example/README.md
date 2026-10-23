# Profile Example

Basic example of how to signup/login using Supabase auth and read and write from your Supabase
database. 

## SQL

You can run the following SQL from your SQL editor of your Supabase console to get started. 

```sql
-- Create a table for Public Profiles
create table profiles (
  id uuid references auth.users not null,
  updated_at timestamp with time zone,
  username text unique,
  avatar_url text,
  website text,

  primary key (id),
  unique(username),
  constraint username_length check (char_length(username) >= 3)
);

alter table profiles
  enable row level security;

create policy "Public profiles are viewable by everyone." on profiles
  for select using (true);

create policy "Users can insert their own profile." on profiles
  for insert with check (auth.uid() = id);

create policy "Users can update own profile." on profiles
  for update using (auth.uid() = id);

-- Set up Realtime! Adds the table to the publication every project has,
-- leaving the tables already in it untouched.
alter publication supabase_realtime
  add table profiles;

-- Set up Storage! Avatars are public to read, and each user writes only to
-- the folder named after their own id, such as `<user id>/avatar.png`.
insert into storage.buckets (id, name, public)
  values ('avatars', 'avatars', true);

create policy "Avatar images are publicly accessible." on storage.objects
  for select using (bucket_id = 'avatars');

create policy "Users can upload their own avatar." on storage.objects
  for insert to authenticated with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );

create policy "Users can update their own avatar." on storage.objects
  for update to authenticated using (
    bucket_id = 'avatars'
    and owner_id = (select auth.uid()::text)
  ) with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
```

## Generated types

The app reads and writes `profiles` through the typed table API,
`client.table(Profiles.table)`, using the row, insert and column types in
`lib/supabase_schema.g.dart`. That file is generated from the database schema
with the [Supabase CLI](https://supabase.com/docs/guides/cli/getting-started)
and the `supabase_typegen` dev dependency. After running the SQL above, generate
it again from your project:

```sh
supabase gen types --lang dart --schema public --project-id YOUR_PROJECT_REF > lib/supabase_schema.g.dart
```

Run the command again after every schema change, so the types keep matching the
database.

## Other Examples

- Flutter user management: https://github.com/supabase/supabase/tree/master/examples/user-management/flutter-user-management
- Extended flutter user management with web support, github login, recovery password flow: https://github.com/phamhieu/supabase-flutter-demo
- Real time chat application: https://github.com/supabase-community/flutter-chat
