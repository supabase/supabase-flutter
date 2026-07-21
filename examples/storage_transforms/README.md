# Storage: uploads and image transformations

A small image gallery that shows how to store and serve files with
`supabase.storage`:

- **Upload** generated PNG bytes to a bucket (`uploadBinary`).
- **List** the objects in the bucket, newest first (`list`).
- **Transform** images on the fly by passing `TransformOptions` (width, height,
  resize mode, quality) to `getPublicUrl`, so the gallery loads a small cropped
  thumbnail and the detail view renders several resized variants.
- **Download** the transformed bytes of an image (`download`).
- **Delete** an object (`remove`).

All Storage access is in
[`lib/storage_repository.dart`](lib/storage_repository.dart), kept separate from
the UI so the calls are easy to read and to drive from an integration test. The
sample images are drawn in memory in
[`lib/sample_image.dart`](lib/sample_image.dart), so the example uploads real
image bytes without bundling asset files or depending on an image picker.

To keep the focus on the Supabase calls, the screen uses plain `setState` and
reloads the gallery after each write rather than pulling in a state management
package. A larger app would typically reach for a state management solution (for
example Riverpod, Bloc or Provider) instead.

The `images` bucket and its access policies come from the shared Supabase config
in [`../supabase`](../supabase): schema in
`migrations/20240603000000_storage_transforms_example.sql`. Image
transformations are enabled in `config.toml`
(`[storage.image_transformation]`). The bucket starts empty; the app uploads its
own images, so there are no seed rows.

## Running

From the `examples` directory, run the launcher and pick `storage_transforms`:

```bash
./run.sh
```

Or run it directly against any project:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```
