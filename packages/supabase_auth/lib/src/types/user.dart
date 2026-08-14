import 'package:collection/collection.dart';
import 'package:supabase_auth/src/types/mfa.dart';
import 'package:supabase_common/supabase_common.dart';

class User {
  final String id;
  final Map<String, dynamic> appMetadata;
  final Map<String, dynamic>? userMetadata;
  final String audience;
  final DateTime? confirmationSentAt;
  final DateTime? recoverySentAt;
  final DateTime? emailChangeSentAt;
  final String? newEmail;
  final DateTime? invitedAt;
  final String? actionLink;
  final String? email;
  final String? phone;
  final DateTime createdAt;
  final DateTime? emailConfirmedAt;
  final DateTime? phoneConfirmedAt;
  final DateTime? lastSignInAt;
  final String? role;
  final DateTime? updatedAt;
  final List<UserIdentity>? identities;
  final List<Factor>? factors;
  final bool isAnonymous;

  const User({
    required this.id,
    required this.appMetadata,
    required this.userMetadata,
    required this.audience,
    this.confirmationSentAt,
    this.recoverySentAt,
    this.emailChangeSentAt,
    this.newEmail,
    this.invitedAt,
    this.actionLink,
    this.email,
    this.phone,
    required this.createdAt,
    this.emailConfirmedAt,
    this.phoneConfirmedAt,
    this.lastSignInAt,
    this.role,
    this.updatedAt,
    this.identities,
    this.factors,
    this.isAnonymous = false,
  });

  /// Returns a `User` object from a map of json
  /// returns `null` if there is no `id` present
  static User? fromJson(Map<String, dynamic> json) {
    if (json['id'] == null) {
      return null;
    }

    return User(
      id: json['id'] ?? '',
      appMetadata: json['app_metadata'] as Map<String, dynamic>? ?? {},
      userMetadata: json['user_metadata'] as Map<String, dynamic>?,
      audience: json['aud'] ?? '',
      confirmationSentAt: tryParseIso8601(json, 'confirmation_sent_at'),
      recoverySentAt: tryParseIso8601(json, 'recovery_sent_at'),
      emailChangeSentAt: tryParseIso8601(json, 'email_change_sent_at'),
      newEmail: json['new_email'],
      invitedAt: tryParseIso8601(json, 'invited_at'),
      actionLink: json['action_link'],
      email: json['email'],
      phone: json['phone'],
      createdAt: parseIso8601(json, 'created_at'),
      emailConfirmedAt: tryParseIso8601(json, 'email_confirmed_at'),
      phoneConfirmedAt: tryParseIso8601(json, 'phone_confirmed_at'),
      lastSignInAt: tryParseIso8601(json, 'last_sign_in_at'),
      role: json['role'],
      updatedAt: tryParseIso8601(json, 'updated_at'),
      identities: json['identities'] != null
          ? List<UserIdentity>.from(
              json['identities']?.map((x) => UserIdentity.fromMap(x)),
            )
          : null,
      factors: json['factors'] != null
          ? List<Factor>.from(json['factors']?.map((x) => Factor.fromJson(x)))
          : null,
      isAnonymous: json['is_anonymous'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'app_metadata': appMetadata,
      'user_metadata': userMetadata,
      'aud': audience,
      'confirmation_sent_at': confirmationSentAt?.toIso8601String(),
      'recovery_sent_at': recoverySentAt?.toIso8601String(),
      'email_change_sent_at': emailChangeSentAt?.toIso8601String(),
      'new_email': newEmail,
      'invited_at': invitedAt?.toIso8601String(),
      'action_link': actionLink,
      'email': email,
      'phone': phone,
      'created_at': createdAt.toIso8601String(),
      'email_confirmed_at': emailConfirmedAt?.toIso8601String(),
      'phone_confirmed_at': phoneConfirmedAt?.toIso8601String(),
      'last_sign_in_at': lastSignInAt?.toIso8601String(),
      'role': role,
      'updated_at': updatedAt?.toIso8601String(),
      'identities': identities?.map((identity) => identity.toJson()).toList(),
      'factors': factors?.map((factor) => factor.toJson()).toList(),
      'is_anonymous': isAnonymous,
    };
  }

  @override
  String toString() {
    return 'User(id: $id, appMetadata: $appMetadata, userMetadata: '
        '$userMetadata, audience: $audience, confirmationSentAt: '
        '$confirmationSentAt, '
        'recoverySentAt: $recoverySentAt, emailChangeSentAt: '
        '$emailChangeSentAt, newEmail: $newEmail, invitedAt: $invitedAt, '
        'actionLink: $actionLink, email: $email, phone: $phone, createdAt: '
        '$createdAt, emailConfirmedAt: $emailConfirmedAt, phoneConfirmedAt: '
        '$phoneConfirmedAt, lastSignInAt: $lastSignInAt, role: $role, '
        'updatedAt: $updatedAt, identities: '
        '$identities, factors: $factors, isAnonymous: $isAnonymous)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final collectionEquals = const DeepCollectionEquality().equals;

    return other is User &&
        other.id == id &&
        collectionEquals(other.appMetadata, appMetadata) &&
        collectionEquals(other.userMetadata, userMetadata) &&
        other.audience == audience &&
        other.confirmationSentAt == confirmationSentAt &&
        other.recoverySentAt == recoverySentAt &&
        other.emailChangeSentAt == emailChangeSentAt &&
        other.newEmail == newEmail &&
        other.invitedAt == invitedAt &&
        other.actionLink == actionLink &&
        other.email == email &&
        other.phone == phone &&
        other.createdAt == createdAt &&
        other.emailConfirmedAt == emailConfirmedAt &&
        other.phoneConfirmedAt == phoneConfirmedAt &&
        other.lastSignInAt == lastSignInAt &&
        other.role == role &&
        other.updatedAt == updatedAt &&
        collectionEquals(other.identities, identities) &&
        collectionEquals(other.factors, factors) &&
        other.isAnonymous == isAnonymous;
  }

  @override
  int get hashCode {
    final collectionHash = const DeepCollectionEquality().hash;

    return id.hashCode ^
        collectionHash(appMetadata) ^
        collectionHash(userMetadata) ^
        audience.hashCode ^
        confirmationSentAt.hashCode ^
        recoverySentAt.hashCode ^
        emailChangeSentAt.hashCode ^
        newEmail.hashCode ^
        invitedAt.hashCode ^
        actionLink.hashCode ^
        email.hashCode ^
        phone.hashCode ^
        createdAt.hashCode ^
        emailConfirmedAt.hashCode ^
        phoneConfirmedAt.hashCode ^
        lastSignInAt.hashCode ^
        role.hashCode ^
        updatedAt.hashCode ^
        collectionHash(identities) ^
        collectionHash(factors) ^
        isAnonymous.hashCode;
  }
}

class UserIdentity {
  final String id;
  final String userId;
  final Map<String, dynamic>? identityData;
  final String identityId;
  final String provider;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final DateTime? updatedAt;

  const UserIdentity({
    required this.id,
    required this.userId,
    required this.identityData,
    required this.identityId,
    required this.provider,
    required this.createdAt,
    required this.lastSignInAt,
    this.updatedAt,
  });

  UserIdentity copyWith({
    String? id,
    String? userId,
    Map<String, dynamic>? identityData,
    String? identityId,
    String? provider,
    DateTime? createdAt,
    DateTime? lastSignInAt,
    DateTime? updatedAt,
  }) {
    return UserIdentity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      identityData: identityData ?? this.identityData,
      identityId: identityId ?? this.identityId,
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
      identityData: (map['identity_data'] as Map?)?.cast(),
      identityId: (map['identity_id'] ?? '') as String,
      provider: map['provider'] as String,
      createdAt: tryParseIso8601(map, 'created_at'),
      lastSignInAt: tryParseIso8601(map, 'last_sign_in_at'),
      updatedAt: tryParseIso8601(map, 'updated_at'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'identity_data': identityData,
      'identity_id': identityId,
      'provider': provider,
      'created_at': createdAt?.toIso8601String(),
      'last_sign_in_at': lastSignInAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'UserIdentity(id: $id, userId: $userId, identityData: '
        '$identityData, identityId: $identityId, provider: $provider, '
        'createdAt: $createdAt, lastSignInAt: $lastSignInAt, updatedAt: '
        '$updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final mapEquals = const DeepCollectionEquality().equals;

    return other is UserIdentity &&
        other.id == id &&
        other.userId == userId &&
        mapEquals(other.identityData, identityData) &&
        other.identityId == identityId &&
        other.provider == provider &&
        other.createdAt == createdAt &&
        other.lastSignInAt == lastSignInAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        userId.hashCode ^
        const DeepCollectionEquality().hash(identityData) ^
        identityId.hashCode ^
        provider.hashCode ^
        createdAt.hashCode ^
        lastSignInAt.hashCode ^
        updatedAt.hashCode;
  }
}
