import 'package:http/http.dart';

/// The transport a Supabase client uses when none is passed to it.
///
/// On web the browser owns the connections, so this is the plain default
/// [Client].
Client createDefaultHttpClient() => Client();
