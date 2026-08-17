/// A dart client for Supabase. It supports database query, authenticate users
/// and listen for realtime changes. This client makes it simple for developers
/// to build secure and scalable products.
library;

export 'package:supabase_functions/supabase_functions.dart';
export 'package:supabase_auth/supabase_auth.dart';
export 'package:postgrest/postgrest.dart';
export 'package:realtime_client/realtime_client.dart';
export 'package:storage_client/storage_client.dart';

export 'src/realtime_client_options.dart';
export 'src/supabase_client.dart';
export 'src/supabase_client_options.dart';
export 'src/supabase_query_builder.dart';
export 'src/supabase_query_schema.dart';
export 'src/supabase_stream_builder.dart';
export 'src/trace_propagation.dart';
