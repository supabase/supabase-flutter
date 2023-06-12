// ignore_for_file: deprecated_member_use_from_same_package

import 'package:collection/collection.dart';
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
      id: json['id'] ?? '',
      appMetadata: json['app_metadata'] as Map<String, dynamic>? ?? {},
      userMetadata: json['user_metadata'] as Map<String, dynamic>?,
      aud: json['aud'] ?? '',
      confirmationSentAt: json['confirmation_sent_at'],
      recoverySentAt: json['recovery_sent_at'],
      emailChangeSentAt: json['email_change_sent_at'],
      newEmail: json['new_email'],
      invitedAt: json['invited_at'],
      actionLink: json['action_link'],
      email: json['email'],
      phone: json['phone'],
      createdAt: json['created_at'] ?? '',
      confirmedAt: json['confirmed_at'],
      emailConfirmedAt: json['email_confirmed_at'],
      phoneConfirmedAt: json['phone_confirmed_at'],
      lastSignInAt: json['last_sign_in_at'],
      role: json['role'],
      updatedAt: json['updated_at'],
      identities: json['identities'] != null
          ? List<UserIdentity>.from(
              json['identities']?.map((x) => UserIdentity.fromMap(x)))
          : null,
      factors: json['factors'] != null
          ? List<Factor>.from(json['factors']?.map((x) => Factor.fromJson(x)))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'app_metadata': appMetadata,
      'user_metadata': userMetadata,
      'aud': aud,
      'confirmation_sent_at': confirmationSentAt,
      'recovery_sent_at': recoverySentAt,
      'email_change_sent_at': emailChangeSentAt,
      'new_email': newEmail,
      'invited_at': invitedAt,
      'action_link': actionLink,
      'email': email,
      'phone': phone,
      'created_at': createdAt,
      'confirmed_at': confirmedAt,
      'email_confirmed_at': emailConfirmedAt,
      'phone_confirmed_at': phoneConfirmedAt,
      'last_sign_in_at': lastSignInAt,
      'role': role,
      'updated_at': updatedAt,
      'identities': identities?.map((identity) => identity.toJson()).toList(),
      'factors': factors?.map((factor) => factor.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'User(id: $id, appMetadata: $appMetadata, userMetadata: $userMetadata, aud: $aud, confirmationSentAt: $confirmationSentAt, recoverySentAt: $recoverySentAt, emailChangeSentAt: $emailChangeSentAt, newEmail: $newEmail, invitedAt: $invitedAt, actionLink: $actionLink, email: $email, phone: $phone, createdAt: $createdAt, confirmedAt: $confirmedAt, emailConfirmedAt: $emailConfirmedAt, phoneConfirmedAt: $phoneConfirmedAt, lastSignInAt: $lastSignInAt, role: $role, updatedAt: $updatedAt, identities: $identities, factors: $factors)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final collectionEquals = const DeepCollectionEquality().equals;

    return other is User &&
        other.id == id &&
        collectionEquals(other.appMetadata, appMetadata) &&
        collectionEquals(other.userMetadata, userMetadata) &&
        other.aud == aud &&
        other.confirmationSentAt == confirmationSentAt &&
        other.recoverySentAt == recoverySentAt &&
        other.emailChangeSentAt == emailChangeSentAt &&
        other.newEmail == newEmail &&
        other.invitedAt == invitedAt &&
        other.actionLink == actionLink &&
        other.email == email &&
        other.phone == phone &&
        other.createdAt == createdAt &&
        other.confirmedAt == confirmedAt &&
        other.emailConfirmedAt == emailConfirmedAt &&
        other.phoneConfirmedAt == phoneConfirmedAt &&
        other.lastSignInAt == lastSignInAt &&
        other.role == role &&
        other.updatedAt == updatedAt &&
        collectionEquals(other.identities, identities) &&
        collectionEquals(other.factors, factors);
  }

  @override
  int get hashCode {
    return id.hashCode ^
        appMetadata.hashCode ^
        userMetadata.hashCode ^
        aud.hashCode ^
        confirmationSentAt.hashCode ^
        recoverySentAt.hashCode ^
        emailChangeSentAt.hashCode ^
        newEmail.hashCode ^
        invitedAt.hashCode ^
        actionLink.hashCode ^
        email.hashCode ^
        phone.hashCode ^
        createdAt.hashCode ^
        confirmedAt.hashCode ^
        emailConfirmedAt.hashCode ^
        phoneConfirmedAt.hashCode ^
        lastSignInAt.hashCode ^
        role.hashCode ^
        updatedAt.hashCode ^
        identities.hashCode ^
        factors.hashCode;
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'identity_data': identityData,
      'provider': provider,
      'created_at': createdAt,
      'last_sign_in_at': lastSignInAt,
      'updated_at': updatedAt,
    };
  }

  @override
  String toString() {
    return 'UserIdentity(id: $id, userId: $userId, identityData: $identityData, provider: $provider, createdAt: $createdAt, lastSignInAt: $lastSignInAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    final mapEquals = const DeepCollectionEquality().equals;

    return other is UserIdentity &&
        other.id == id &&
        other.userId == userId &&
        mapEquals(other.identityData, identityData) &&
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
