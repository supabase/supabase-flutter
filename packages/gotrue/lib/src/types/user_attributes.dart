// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:collection/collection.dart';

class UserAttributes {
  /// The user's email.
  String? email;

  /// The user's phone.
  String? phone;

  /// The user's password.
  String? password;

  /// The nonce sent for reauthentication if the user's password is to be updated.
  ///
  /// Call reauthenticate() to obtain the nonce first.
  String? nonce;

  /// A custom data object to store the user's metadata. This maps to the `auth.users.user_metadata` column.
  ///
  /// The `data` should be a JSON object that includes user-specific info, such as their first and last name.
  Object? data;

  UserAttributes({
    this.email,
    this.phone,
    this.password,
    this.nonce,
    this.data,
  }) : assert(data == null || data is List || data is Map);

  Map<String, dynamic> toJson() {
    return {
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (nonce != null) 'nonce': nonce,
      if (password != null) 'password': password,
      if (data != null) 'data': data,
    };
  }

  @override
  bool operator ==(covariant UserAttributes other) {
    if (identical(this, other)) return true;

    return other.email == email &&
        other.phone == phone &&
        other.password == password &&
        other.nonce == nonce &&
        other.data == data;
  }

  @override
  int get hashCode {
    return email.hashCode ^
        phone.hashCode ^
        password.hashCode ^
        nonce.hashCode ^
        data.hashCode;
  }
}

class AdminUserAttributes extends UserAttributes {
  /// A custom data object to store the user's metadata. This maps to the `auth.users.user_metadata` column.
  ///
  /// Only a service role can modify.
  ///
  /// The `user_metadata` should be a JSON object that includes user-specific info, such as their first and last name.
  ///
  /// Note: When using the GoTrueAdminApi and wanting to modify a user's metadata,
  /// this attribute is used instead of UserAttributes data.
  final Map<String, dynamic>? userMetadata;

  /// A custom data object to store the user's application specific metadata. This maps to the `auth.users.app_metadata` column.
  ///
  /// Only a service role can modify.
  ///
  /// The `app_metadata` should be a JSON object that includes app-specific info, such as identity providers, roles, and other
  /// access control information.
  final Map<String, dynamic>? appMetadata;

  /// Confirms the user's email address if set to true.
  ///
  /// Only a service role can modify.
  final bool? emailConfirm;

  /// Confirms the user's phone number if set to true.
  ///
  /// Only a service role can modify.
  final bool? phoneConfirm;

  /// Determines how long a user is banned for.
  ///
  /// The format for the ban duration follows a strict sequence of decimal numbers with a unit suffix.
  /// Valid time units are "ns", "us" (or "µs"), "ms", "s", "m", "h".
  ///
  /// For example, some possible durations include: '300ms', '2h45m'.
  ///
  /// Setting the ban duration to 'none' lifts the ban on the user.
  final String? banDuration;

  AdminUserAttributes({
    super.email,
    super.phone,
    super.password,
    super.data,
    this.userMetadata,
    this.appMetadata,
    this.emailConfirm,
    this.phoneConfirm,
    this.banDuration,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (password != null) 'password': password,
      if (data != null) 'data': data,
      if (userMetadata != null) 'user_metadata': userMetadata,
      if (appMetadata != null) 'app_metadata': appMetadata,
      if (emailConfirm != null) 'email_confirm': emailConfirm,
      if (phoneConfirm != null) 'phone_confirm': phoneConfirm,
      if (banDuration != null) 'ban_duration': banDuration,
    };
  }

  @override
  bool operator ==(covariant AdminUserAttributes other) {
    if (identical(this, other)) return true;
    final mapEquals = const DeepCollectionEquality().equals;

    return mapEquals(other.userMetadata, userMetadata) &&
        mapEquals(other.appMetadata, appMetadata) &&
        other.emailConfirm == emailConfirm &&
        other.phoneConfirm == phoneConfirm &&
        other.banDuration == banDuration;
  }

  @override
  int get hashCode {
    return userMetadata.hashCode ^
        appMetadata.hashCode ^
        emailConfirm.hashCode ^
        phoneConfirm.hashCode ^
        banDuration.hashCode;
  }
}
