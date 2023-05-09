import 'package:storage_client/src/version.dart';

class Constants {
  static const Map<String, String> defaultHeaders = {
    'X-Client-Info': 'storage-dart/$version',
  };
}
