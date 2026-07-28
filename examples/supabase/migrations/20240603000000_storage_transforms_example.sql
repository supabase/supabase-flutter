-- Schema for the "Storage: uploads and image transformations" example.
--
-- A single public bucket that the example uploads generated PNGs to and reads
-- back from, applying image transformations on the way out.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'images',
  'images',
  true,
  1048576,
  array['image/png', 'image/jpeg', 'image/webp']
)
on conflict (id) do nothing;

-- The example runs unauthenticated with the publishable (anon) key. A public
-- bucket already serves reads without a policy; these policies additionally let
-- the demo list, upload, overwrite and delete objects in the `images` bucket
-- without signing in. A real app would scope these policies to the signed in
-- user instead.
create policy "Anyone can view images"
  on storage.objects for select using (bucket_id = 'images');

create policy "Anyone can upload images"
  on storage.objects for insert with check (bucket_id = 'images');

create policy "Anyone can update images"
  on storage.objects for update
  using (bucket_id = 'images') with check (bucket_id = 'images');

create policy "Anyone can delete images"
  on storage.objects for delete using (bucket_id = 'images');
