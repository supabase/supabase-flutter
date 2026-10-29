import 'package:collection/collection.dart';
import 'package:supabase_common/supabase_common.dart';

/// Format of the SAML `NameID` a single sign-on identity provider asserts to
/// identify the user.
enum SAMLNameIdFormat {
  /// A stable, opaque identifier that stays the same across sign-ins.
  persistent('urn:oasis:names:tc:SAML:2.0:nameid-format:persistent'),

  /// The user's email address.
  emailAddress('urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress'),

  /// A one-time identifier that changes on every sign-in.
  transient('urn:oasis:names:tc:SAML:2.0:nameid-format:transient'),

  /// Leaves the format up to the identity provider.
  unspecified('urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified');

  const SAMLNameIdFormat(this.urn);

  /// The URN that identifies this format in SAML metadata and on the wire.
  final String urn;

  /// Parses a format from its [urn], returning null for one this version of
  /// the client does not recognize.
  static SAMLNameIdFormat? fromUrn(String urn) {
    return SAMLNameIdFormat.values.firstWhereOrNull(
      (format) => format.urn == urn,
    );
  }
}

/// Where the SAML 2.0 metadata of a single sign-on identity provider comes
/// from.
sealed class SAMLMetadata {
  const SAMLMetadata();

  /// Metadata the Auth server fetches from [url], which must use HTTPS.
  ///
  /// The server fetches and parses the document before answering, so the
  /// request takes as long as that outbound fetch.
  const factory SAMLMetadata.url(Uri url) = SAMLMetadataUrl;

  /// Metadata given inline as an XML document.
  const factory SAMLMetadata.xml(String xml) = SAMLMetadataXml;

  Map<String, dynamic> toJson();
}

/// SAML metadata the Auth server fetches from [url].
final class SAMLMetadataUrl extends SAMLMetadata {
  const SAMLMetadataUrl(this.url);

  /// The HTTPS URL the metadata document is served from.
  final Uri url;

  @override
  Map<String, dynamic> toJson() => {'metadata_url': url.toString()};
}

/// SAML metadata given inline as an XML document.
final class SAMLMetadataXml extends SAMLMetadata {
  const SAMLMetadataXml(this.xml);

  /// The metadata XML document.
  final String xml;

  @override
  Map<String, dynamic> toJson() => {'metadata_xml': xml};
}

/// How one user attribute is read from the SAML assertion.
class SAMLAttribute {
  const SAMLAttribute({
    this.name,
    this.names,
    this.defaultValue,
    this.array = false,
  });

  factory SAMLAttribute.fromJson(Map<String, dynamic> json) {
    return SAMLAttribute(
      name: json.field('name'),
      names: json.listOf('names'),
      defaultValue: json['default'],
      array: json.field('array') ?? false,
    );
  }

  /// The name of the assertion attribute to read.
  final String? name;

  /// Assertion attribute names to try in order, the first one present wins.
  final List<String>? names;

  /// The value used when the assertion carries none of the attributes.
  final Object? defaultValue;

  /// Whether to keep every value of a multi-valued attribute instead of only
  /// the first one.
  final bool array;

  Map<String, dynamic> toJson() => {
    'name': ?name,
    'names': ?names,
    'default': ?defaultValue,
    if (array) 'array': true,
  };
}

/// Maps SAML assertion attributes to user metadata keys.
class SAMLAttributeMapping {
  const SAMLAttributeMapping(this.keys);

  factory SAMLAttributeMapping.fromJson(Map<String, dynamic> json) {
    final keys =
        json.field<Map<dynamic, dynamic>?>('keys')?.cast<String, dynamic>() ??
        const {};
    return SAMLAttributeMapping({
      for (final key in keys.keys) key: SAMLAttribute.fromJson(keys.field(key)),
    });
  }

  /// The attribute to read for each user metadata key.
  final Map<String, SAMLAttribute> keys;

  Map<String, dynamic> toJson() => {
    'keys': {
      for (final MapEntry(:key, :value) in keys.entries) key: value.toJson(),
    },
  };
}

/// The SAML 2.0 configuration of a single sign-on identity provider.
class SAMLProvider {
  const SAMLProvider({
    required this.entityId,
    this.metadataXml,
    this.metadataUrl,
    this.attributeMapping,
    this.nameIdFormat,
  });

  factory SAMLProvider.fromJson(Map<String, dynamic> json) {
    final metadataUrl = json.field<String?>('metadata_url');
    final attributeMapping = json.field<Map<dynamic, dynamic>?>(
      'attribute_mapping',
    );
    final nameIdFormat = json.field<String?>('name_id_format');
    return SAMLProvider(
      entityId: json.field('entity_id'),
      metadataXml: json.field('metadata_xml'),
      metadataUrl: metadataUrl == null ? null : Uri.parse(metadataUrl),
      attributeMapping: attributeMapping == null
          ? null
          : SAMLAttributeMapping.fromJson(attributeMapping.cast()),
      nameIdFormat: nameIdFormat == null
          ? null
          : SAMLNameIdFormat.fromUrn(nameIdFormat),
    );
  }

  /// The entity ID from the identity provider's metadata.
  final String entityId;

  /// The identity provider's metadata XML.
  ///
  /// Null on providers returned by `listProviders`, which leaves it out.
  final String? metadataXml;

  /// The URL the metadata was fetched from, when it was registered by URL.
  final Uri? metadataUrl;

  /// How assertion attributes map to user metadata.
  final SAMLAttributeMapping? attributeMapping;

  /// The `NameID` format requested from the identity provider.
  final SAMLNameIdFormat? nameIdFormat;
}

/// A single sign-on identity provider registered with Supabase Auth.
class SSOProvider {
  const SSOProvider({
    required this.id,
    this.resourceId,
    this.disabled = false,
    this.saml,
    this.domains = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory SSOProvider.fromJson(Map<String, dynamic> json) {
    final saml = json.field<Map<dynamic, dynamic>?>('saml');
    final domains = json.listOf<Map<String, dynamic>>('domains') ?? const [];
    return SSOProvider(
      id: json.field('id'),
      resourceId: json.field('resource_id'),
      disabled: json.field('disabled') ?? false,
      saml: saml == null ? null : SAMLProvider.fromJson(saml.cast()),
      domains: [for (final domain in domains) domain.field('domain')],
      createdAt: DateTime.parse(json.field('created_at')),
      updatedAt: DateTime.parse(json.field('updated_at')),
    );
  }

  /// The provider's UUID.
  final String id;

  /// An identifier of your choosing that the provider can also be addressed
  /// by, as `resource_<resourceId>` in place of [id].
  final String? resourceId;

  /// Whether sign-in through this provider is turned off.
  final bool disabled;

  /// The provider's SAML 2.0 configuration.
  final SAMLProvider? saml;

  /// The email domains whose users sign in through this provider.
  final List<String> domains;

  final DateTime createdAt;
  final DateTime updatedAt;
}

/// The options to register a single sign-on identity provider with.
class CreateSSOProviderOptions {
  const CreateSSOProviderOptions({
    required this.metadata,
    this.domains,
    this.attributeMapping,
    this.nameIdFormat,
    this.resourceId,
    this.disabled,
  });

  /// The identity provider's SAML 2.0 metadata.
  final SAMLMetadata metadata;

  /// The email domains whose users sign in through this provider.
  final List<String>? domains;

  /// How assertion attributes map to user metadata.
  final SAMLAttributeMapping? attributeMapping;

  /// The `NameID` format to request from the identity provider.
  final SAMLNameIdFormat? nameIdFormat;

  /// An identifier of your choosing to address the provider by.
  final String? resourceId;

  /// Whether to register the provider with sign-in turned off.
  final bool? disabled;

  Map<String, dynamic> toJson() => {
    'type': 'saml',
    ...metadata.toJson(),
    'domains': ?domains,
    'attribute_mapping': ?attributeMapping?.toJson(),
    'name_id_format': ?nameIdFormat?.urn,
    'resource_id': ?resourceId,
    'disabled': ?disabled,
  };
}

/// The changes to apply to a registered single sign-on identity provider.
///
/// A null field keeps the stored value, except for [nameIdFormat], which the
/// server clears when it is not sent.
class UpdateSSOProviderOptions {
  const UpdateSSOProviderOptions({
    required this.nameIdFormat,
    this.metadata,
    this.domains,
    this.attributeMapping,
    this.resourceId,
    this.disabled,
  });

  /// The `NameID` format to request from the identity provider.
  ///
  /// Required because null clears the stored format. Pass the provider's
  /// current [SAMLProvider.nameIdFormat] to keep it.
  final SAMLNameIdFormat? nameIdFormat;

  /// New SAML metadata, which must carry the provider's current entity ID.
  final SAMLMetadata? metadata;

  /// Replaces the provider's email domains. An empty list removes them all.
  final List<String>? domains;

  /// Replaces the attribute mapping. A mapping with no keys clears it.
  final SAMLAttributeMapping? attributeMapping;

  /// A new resource ID. An empty string removes the stored one.
  final String? resourceId;

  /// Turns sign-in through the provider off or back on.
  final bool? disabled;

  Map<String, dynamic> toJson() => {
    ...?metadata?.toJson(),
    'domains': ?domains,
    'attribute_mapping': ?attributeMapping?.toJson(),
    'name_id_format': ?nameIdFormat?.urn,
    'resource_id': ?resourceId,
    'disabled': ?disabled,
  };
}
