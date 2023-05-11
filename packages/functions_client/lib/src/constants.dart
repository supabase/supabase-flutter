import 'package:functions_client/src/version.dart';

class Constants {
  static const defaultHeaders = {
    'Content-Type': 'application/json',
    'X-Client-Info': 'functions-dart/$version',
  };
}
