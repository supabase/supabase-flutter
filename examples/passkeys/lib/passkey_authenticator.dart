import 'dart:convert';
import 'dart:js_interop';

/// Performs the browser side of the WebAuthn ceremony.
///
/// The Supabase passkey API hands us the WebAuthn options as plain JSON maps
/// and expects the resulting credential back in the same JSON format. The
/// browser exposes exactly that through `PublicKeyCredential.parse*FromJSON`
/// and `credential.toJSON()`, so all this file does is bridge those calls.
class PasskeyAuthenticator {
  const PasskeyAuthenticator();

  /// Prompts the user to create a passkey for [options] and returns the new
  /// credential as a JSON map.
  Future<Map<String, dynamic>> create(Map<String, dynamic> options) async {
    final publicKey = _PublicKeyCredential.parseCreationOptionsFromJSON(
      _toJs(options),
    );
    final credential = await _credentials
        .create(_CredentialCreationOptions(publicKey: publicKey))
        .toDart;
    return _fromJs((credential! as _PublicKeyCredential).toJSON());
  }

  /// Prompts the user to sign in with a passkey for [options] and returns the
  /// assertion as a JSON map.
  Future<Map<String, dynamic>> get(Map<String, dynamic> options) async {
    final publicKey = _PublicKeyCredential.parseRequestOptionsFromJSON(
      _toJs(options),
    );
    final credential = await _credentials
        .get(_CredentialRequestOptions(publicKey: publicKey))
        .toDart;
    return _fromJs((credential! as _PublicKeyCredential).toJSON());
  }
}

JSObject _toJs(Map<String, dynamic> map) =>
    _jsonParse(jsonEncode(map).toJS) as JSObject;

Map<String, dynamic> _fromJs(JSObject object) =>
    jsonDecode(_jsonStringify(object).toDart) as Map<String, dynamic>;

@JS('navigator.credentials')
external _CredentialsContainer get _credentials;

@JS('JSON.parse')
external JSAny _jsonParse(JSString text);

@JS('JSON.stringify')
external JSString _jsonStringify(JSObject value);

extension type _CredentialsContainer._(JSObject _) implements JSObject {
  external JSPromise<JSObject?> create(_CredentialCreationOptions options);
  external JSPromise<JSObject?> get(_CredentialRequestOptions options);
}

extension type _CredentialCreationOptions._(JSObject _) implements JSObject {
  external factory _CredentialCreationOptions({JSObject publicKey});
}

extension type _CredentialRequestOptions._(JSObject _) implements JSObject {
  external factory _CredentialRequestOptions({JSObject publicKey});
}

@JS('PublicKeyCredential')
extension type _PublicKeyCredential._(JSObject _) implements JSObject {
  external static JSObject parseCreationOptionsFromJSON(JSObject options);
  external static JSObject parseRequestOptionsFromJSON(JSObject options);
  external JSObject toJSON();
}
