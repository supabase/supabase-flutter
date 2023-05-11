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

-- Set up Realtime!
begin;
  drop publication if exists supabase_realtime;
  create publication supabase_realtime;
commit;
alter publication supabase_realtime
  add table profiles;

-- Set up Storage!
insert into storage.buckets (id, name)
  values ('avatars', 'avatars');

create policy "Avatar images are publicly accessible." on storage.objects
  for select using (bucket_id = 'avatars');

create policy "Anyone can upload an avatar." on storage.objects
  for insert with check (bucket_id = 'avatars');

create policy "Anyone can update an avatar." on storage.objects
  for update with check (bucket_id = 'avatars');
```

## Other Examples

- Flutter user management: https://github.com/supabase/supabase/tree/master/examples/user-management/flutter-user-management
- Extended flutter user management with web support, github login, recovery password flow: https://github.com/phamhieu/supabase-flutter-demo
- Real time chat application: https://github.com/supabase-community/flutter-chat
