import 'package:gotrue/gotrue.dart' show User;

class AuthUser extends User {
  AuthUser({
    required super.id,
    required super.appMetadata,
    required super.userMetadata,
    required super.aud,
    required super.email,
    required super.phone,
    required super.createdAt,
    super.confirmedAt,
    super.emailConfirmedAt,
    super.phoneConfirmedAt,
    super.lastSignInAt,
    required String super.role,
    required String super.updatedAt,
  });
}
