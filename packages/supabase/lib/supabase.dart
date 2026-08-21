/// A dart client for Supabase. It supports database query, authenticate users
/// and listen for realtime changes. This client makes it simple for developers
/// to build secure and scalable products.
library;

export 'package:supabase_functions/supabase_functions.dart';
export 'package:supabase_auth/supabase_auth.dart';
export 'package:postgrest/postgrest.dart';
export 'package:supabase_realtime/supabase_realtime.dart';
export 'package:supabase_storage/supabase_storage.dart';
export 'package:yet_another_json_isolate/yet_another_json_isolate.dart'
    show YAJsonIsolate;

export 'src/realtime_client_options.dart';
export 'src/supabase_client.dart';
export 'src/supabase_client_options.dart';
export 'src/supabase_query_builder.dart';
export 'src/supabase_query_schema.dart';
export 'src/supabase_stream_builder.dart';
export 'src/trace_propagation.dart';
