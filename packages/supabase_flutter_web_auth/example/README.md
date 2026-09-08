# supabase_flutter_web_auth_example

Demonstrates using `supabase_flutter_web_auth`'s `FlutterWebAuth2OAuthLauncher`
with `supabase_flutter`.

Platform folders (`android/`, `ios/`, etc.) are not checked in. Before running,
generate the ones you want to test on:

```sh
flutter create .
```

Then fill in `SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` in `lib/main.dart`,
register the redirect scheme (see the package README's Setup section), and
run the app.
