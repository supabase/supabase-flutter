import 'package:gotrue/gotrue.dart' show User;

class AuthUser extends User {
  AuthUser({
    required String id,
    required Map<String, dynamic> appMetadata,
    required Map<String, dynamic> userMetadata,
    required String aud,
    required String? email,
    required String? phone,
    required String createdAt,
    String? confirmedAt,
    String? emailConfirmedAt,
    String? phoneConfirmedAt,
    String? lastSignInAt,
    required String role,
    required String updatedAt,
  }) : super(
          id: id,
          appMetadata: appMetadata,
          userMetadata: userMetadata,
          aud: aud,
          email: email,
          phone: phone,
          createdAt: createdAt,
          // ignore: deprecated_member_use
          confirmedAt: confirmedAt,
          emailConfirmedAt: emailConfirmedAt,
          phoneConfirmedAt: phoneConfirmedAt,
          lastSignInAt: lastSignInAt,
          role: role,
          updatedAt: updatedAt,
        );
}
