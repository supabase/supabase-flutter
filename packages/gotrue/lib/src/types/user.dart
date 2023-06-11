import 'package:gotrue/src/types/mfa.dart';

class User {
  final String id;
  final Map<String, dynamic> appMetadata;
  final Map<String, dynamic>? userMetadata;
  final String aud;
  final String? confirmationSentAt;
  final String? recoverySentAt;
  final String? emailChangeSentAt;
  final String? newEmail;
  final String? invitedAt;
  final String? actionLink;
  final String? email;
  final String? phone;
  final String createdAt;
  @Deprecated('Use emailConfirmedAt instead')
  final String? confirmedAt;
  final String? emailConfirmedAt;
  final String? phoneConfirmedAt;
  final String? lastSignInAt;
  final String? role;
  final String? updatedAt;
  final List<UserIdentity>? identities;
  final List<Factor>? factors;

  const User({
    required this.id,
    required this.appMetadata,
    required this.userMetadata,
    required this.aud,
    this.confirmationSentAt,
    this.recoverySentAt,
    this.emailChangeSentAt,
    this.newEmail,
    this.invitedAt,
    this.actionLink,
    this.email,
    this.phone,
    required this.createdAt,
    @Deprecated('Use emailConfirmedAt instead') this.confirmedAt,
    this.emailConfirmedAt,
    this.phoneConfirmedAt,
    this.lastSignInAt,
    this.role,
    this.updatedAt,
    this.identities,
    this.factors,
  });

  /// Returns a `User` object from a map of json
  /// returns `null` if there is no `id` present
  static User? fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) {
      return null;
    }
    return User(
      id: json['id'] as String,
      appMetadata: json['app_metadata'] as Map<String, dynamic>,
      userMetadata: json['user_metadata'] as Map<String, dynamic>?,
      aud: json['aud'] as String,
      confirmationSentAt: json['confirmation_sent_at'] as String?,
      recoverySentAt: json['recovery_sent_at'] as String?,
      emailChangeSentAt: json['email_change_sent_at'] as String?,
      newEmail: json['new_email'] as String?,
      invitedAt: json['invited_at'] as String?,
      actionLink: json['action_link'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      createdAt: json['created_at'] as String,
      // ignore: deprecated_member_use_from_same_package
      confirmedAt: json['confirmed_at'] as String?,
      emailConfirmedAt: json['email_confirmed_at'] as String?,
      phoneConfirmedAt: json['phone_confirmed_at'] as String?,
      lastSignInAt: json['last_sign_in_at'] as String?,
      role: json['role'] as String?,
      updatedAt: json['updated_at'] as String?,
      identities:
          (json['identities'] as List?)?.cast<Map<String, dynamic>>().map((e) {
        return UserIdentity.fromMap(e);
      }).toList(),
      factors:
          (json['factors'] as List?)?.cast<Map<String, dynamic>>().map((e) {
        return Factor.fromJson(e);
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'app_metadata': appMetadata,
        'user_metadata': userMetadata,
        'aud': aud,
        'email': email,
        'phone': phone,
        'created_at': createdAt,
        // ignore: deprecated_member_use_from_same_package
        'confirmed_at': confirmedAt,
        'email_confirmed_at': emailConfirmedAt,
        'phone_confirmed_at': phoneConfirmedAt,
        'last_sign_in_at': lastSignInAt,
        'role': role,
        'updated_at': updatedAt,
      };

  @override
  String toString() {
    return 'User(id: $id, appMetadata: $appMetadata, userMetadata: $userMetadata, aud: $aud, confirmationSentAt: $confirmationSentAt, recoverySentAt: $recoverySentAt, emailChangeSentAt: $emailChangeSentAt, newEmail: $newEmail, invitedAt: $invitedAt, actionLink: $actionLink, email: $email, phone: $phone, createdAt: $createdAt, confirmedAt: $confirmedAt, emailConfirmedAt: $emailConfirmedAt, phoneConfirmedAt: $phoneConfirmedAt, lastSignInAt: $lastSignInAt, role: $role, updatedAt: $updatedAt, identities: $identities, factors: $factors)';
  }
}

class UserIdentity {
  final String id;
  final String userId;
  final Map<String, dynamic>? identityData;
  final String provider;
  final String? createdAt;
  final String? lastSignInAt;
  final String? updatedAt;

  const UserIdentity({
    required this.id,
    required this.userId,
    required this.identityData,
    required this.provider,
    required this.createdAt,
    required this.lastSignInAt,
    this.updatedAt,
  });

  UserIdentity copyWith({
    String? id,
    String? userId,
    Map<String, dynamic>? identityData,
    String? provider,
    String? createdAt,
    String? lastSignInAt,
    String? updatedAt,
  }) {
    return UserIdentity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      identityData: identityData ?? this.identityData,
      provider: provider ?? this.provider,
      createdAt: createdAt ?? this.createdAt,
      lastSignInAt: lastSignInAt ?? this.lastSignInAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserIdentity.fromMap(Map<String, dynamic> map) {
    return UserIdentity(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      identityData: (map['identity_data'] as Map?)?.cast<String, dynamic>(),
      provider: map['provider'] as String,
      createdAt: map['created_at'] as String?,
      lastSignInAt: map['last_sign_in_at'] as String?,
      updatedAt: map['updated_at'] as String?,
    );
  }

  @override
  String toString() {
    return 'UserIdentity(id: $id, userId: $userId, identityData: $identityData, provider: $provider, createdAt: $createdAt, lastSignInAt: $lastSignInAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserIdentity &&
        other.id == id &&
        other.userId == userId &&
        other.identityData == identityData &&
        other.provider == provider &&
        other.createdAt == createdAt &&
        other.lastSignInAt == lastSignInAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        identityData.hashCode ^
        provider.hashCode ^
        createdAt.hashCode ^
        lastSignInAt.hashCode ^
        updatedAt.hashCode;
  }
}
