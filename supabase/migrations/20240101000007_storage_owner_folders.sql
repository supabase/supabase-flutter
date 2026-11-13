-- In the buckets named owner-folders-*, a signed-in user may only write and
-- read the objects under a folder named after their user id, as the storage
-- access control guide sets it up. The supabase package tests that one user
-- cannot continue, cancel or read the resumable upload of another there.
create policy "owner folders insert" on storage.objects
for insert to authenticated
with check (
  bucket_id like 'owner-folders-%'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "owner folders select" on storage.objects
for select to authenticated
using (
  bucket_id like 'owner-folders-%'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "owner folders update" on storage.objects
for update to authenticated
using (
  bucket_id like 'owner-folders-%'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);

create policy "owner folders delete" on storage.objects
for delete to authenticated
using (
  bucket_id like 'owner-folders-%'
  and (storage.foldername(name))[1] = (select auth.uid()::text)
);
