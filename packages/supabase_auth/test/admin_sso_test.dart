import 'package:supabase_auth/supabase_auth.dart';
import 'package:test/test.dart';

import 'utils.dart';

const _providerId = '6d1b8e0b-9a5f-4b3e-8f1c-2f0d4b7a9c11';

Map<String, dynamic> _providerJson({
  bool includeMetadataXml = true,
  Map<String, dynamic>? attributeMapping,
  String? nameIdFormat,
}) => {
  'id': _providerId,
  'resource_id': 'acme',
  'disabled': null,
  'saml': {
    'entity_id': 'https://idp.example.com/metadata',
    if (includeMetadataXml) 'metadata_xml': '<EntityDescriptor/>',
    'metadata_url': 'https://idp.example.com/metadata',
    'attribute_mapping': ?attributeMapping,
    'name_id_format': ?nameIdFormat,
  },
  'domains': [
    {'domain': 'acme.com'},
    {'domain': 'acme.org'},
  ],
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-02T00:00:00Z',
};

void main() {
  AuthClient clientWith(MockSupabaseHttpClient mockClient) => AuthClient(
    url: 'http://localhost:9999',
    httpClient: mockClient,
    asyncStorage: TestAsyncStorage(),
  );

  group('SAMLNameIdFormat', () {
    test('encodes each format as its SAML URN', () {
      expect(
        SAMLNameIdFormat.persistent.urn,
        'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent',
      );
      expect(
        SAMLNameIdFormat.emailAddress.urn,
        'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
      );
      expect(
        SAMLNameIdFormat.transient.urn,
        'urn:oasis:names:tc:SAML:2.0:nameid-format:transient',
      );
      expect(
        SAMLNameIdFormat.unspecified.urn,
        'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified',
      );
    });

    test('parses every format from its URN', () {
      for (final format in SAMLNameIdFormat.values) {
        expect(SAMLNameIdFormat.fromUrn(format.urn), format);
      }
    });

    test('parses an unrecognized URN as null', () {
      expect(SAMLNameIdFormat.fromUrn('urn:example:unknown'), isNull);
    });
  });

  group('CreateSSOProviderOptions', () {
    test('serializes a metadata URL with only the required fields', () {
      final options = CreateSSOProviderOptions(
        metadata: SAMLMetadata.url(
          Uri.parse('https://idp.example.com/metadata'),
        ),
      );

      expect(options.toJson(), {
        'type': 'saml',
        'metadata_url': 'https://idp.example.com/metadata',
      });
    });

    test('serializes metadata XML and every optional field', () {
      final options = CreateSSOProviderOptions(
        metadata: const SAMLMetadata.xml('<EntityDescriptor/>'),
        domains: ['acme.com'],
        attributeMapping: const SAMLAttributeMapping({
          'email': SAMLAttribute(name: 'mail'),
          'groups': SAMLAttribute(
            names: ['memberOf', 'groups'],
            defaultValue: ['users'],
            array: true,
          ),
        }),
        nameIdFormat: SAMLNameIdFormat.persistent,
        resourceId: 'acme',
        disabled: true,
      );

      expect(options.toJson(), {
        'type': 'saml',
        'metadata_xml': '<EntityDescriptor/>',
        'domains': ['acme.com'],
        'attribute_mapping': {
          'keys': {
            'email': {'name': 'mail'},
            'groups': {
              'names': ['memberOf', 'groups'],
              'default': ['users'],
              'array': true,
            },
          },
        },
        'name_id_format':
            'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent',
        'resource_id': 'acme',
        'disabled': true,
      });
    });
  });

  group('UpdateSSOProviderOptions', () {
    test('omits the fields that keep their stored value', () {
      const options = UpdateSSOProviderOptions(
        nameIdFormat: SAMLNameIdFormat.emailAddress,
      );

      expect(options.toJson(), {
        'name_id_format':
            'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
      });
    });

    test('sends no name_id_format when it is null, which clears it', () {
      const options = UpdateSSOProviderOptions(nameIdFormat: null);

      expect(options.toJson(), isEmpty);
    });

    test('sends empty domains and attribute mapping to clear them', () {
      const options = UpdateSSOProviderOptions(
        nameIdFormat: null,
        domains: [],
        attributeMapping: SAMLAttributeMapping({}),
      );

      expect(options.toJson(), {
        'domains': <String>[],
        'attribute_mapping': {'keys': <String, dynamic>{}},
      });
    });

    test('serializes new metadata, resource ID and disabled state', () {
      final options = UpdateSSOProviderOptions(
        nameIdFormat: null,
        metadata: SAMLMetadata.url(
          Uri.parse('https://idp.example.com/metadata'),
        ),
        resourceId: '',
        disabled: false,
      );

      expect(options.toJson(), {
        'metadata_url': 'https://idp.example.com/metadata',
        'resource_id': '',
        'disabled': false,
      });
    });
  });

  group('SSOProvider.fromJson', () {
    test('parses a provider with its SAML configuration', () {
      final provider = SSOProvider.fromJson(
        _providerJson(
          attributeMapping: {
            'keys': {
              'email': {'name': 'mail'},
              'groups': {
                'names': ['memberOf'],
                'array': true,
              },
            },
          },
          nameIdFormat: SAMLNameIdFormat.transient.urn,
        ),
      );

      expect(provider.id, _providerId);
      expect(provider.resourceId, 'acme');
      expect(provider.disabled, isFalse);
      expect(provider.domains, ['acme.com', 'acme.org']);
      expect(provider.createdAt, DateTime.utc(2026));
      expect(provider.updatedAt, DateTime.utc(2026, 1, 2));

      final saml = provider.saml!;
      expect(saml.entityId, 'https://idp.example.com/metadata');
      expect(saml.metadataXml, '<EntityDescriptor/>');
      expect(saml.metadataUrl, Uri.parse('https://idp.example.com/metadata'));
      expect(saml.nameIdFormat, SAMLNameIdFormat.transient);
      expect(saml.attributeMapping!.keys['email']!.name, 'mail');
      expect(saml.attributeMapping!.keys['groups']!.names, ['memberOf']);
      expect(saml.attributeMapping!.keys['groups']!.array, isTrue);
    });

    test('leaves the metadata XML null when the server omits it', () {
      final provider = SSOProvider.fromJson(
        _providerJson(includeMetadataXml: false),
      );

      expect(provider.saml!.metadataXml, isNull);
      expect(provider.saml!.attributeMapping, isNull);
      expect(provider.saml!.nameIdFormat, isNull);
    });
  });

  group('AuthAdminSSOApi', () {
    test('listProviders() sends the resource ID filters', () async {
      final mockClient = MockSupabaseHttpClient()
        ..stub({
          'items': [_providerJson(includeMetadataXml: false)],
        });

      final providers = await clientWith(mockClient).admin.sso.listProviders(
        resourceIdPrefix: 'ac',
      );

      expect(providers.single.id, _providerId);
      final request = mockClient
          .requestsTo(
            '/admin/sso/providers',
            method: HttpMethod.get,
          )
          .single;
      expect(request.queryParameters, {'resource_id_prefix': 'ac'});
    });

    test('createProvider() accepts the 201 the server answers with', () async {
      final mockClient = MockSupabaseHttpClient()
        ..stub(_providerJson(), statusCode: 201);

      final provider = await clientWith(mockClient).admin.sso.createProvider(
        const CreateSSOProviderOptions(
          metadata: SAMLMetadata.xml('<EntityDescriptor/>'),
          domains: ['acme.com'],
        ),
      );

      expect(provider.id, _providerId);
      final request = mockClient
          .requestsTo(
            '/admin/sso/providers',
            method: HttpMethod.post,
          )
          .single;
      expect(request.jsonBody, {
        'type': 'saml',
        'metadata_xml': '<EntityDescriptor/>',
        'domains': ['acme.com'],
      });
    });

    test('getProvider() addresses a provider by resource ID', () async {
      final mockClient = MockSupabaseHttpClient()..stub(_providerJson());

      await clientWith(mockClient).admin.sso.getProvider('resource_acme');

      expect(
        mockClient.requestsTo(
          '/admin/sso/providers/resource_acme',
          method: HttpMethod.get,
        ),
        hasLength(1),
      );
    });

    test('updateProvider() sends the options with PUT', () async {
      final mockClient = MockSupabaseHttpClient()..stub(_providerJson());

      await clientWith(mockClient).admin.sso.updateProvider(
        _providerId,
        const UpdateSSOProviderOptions(
          nameIdFormat: SAMLNameIdFormat.persistent,
          domains: ['acme.com'],
        ),
      );

      final request = mockClient
          .requestsTo(
            '/admin/sso/providers/$_providerId',
            method: HttpMethod.put,
          )
          .single;
      expect(request.jsonBody, {
        'domains': ['acme.com'],
        'name_id_format':
            'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent',
      });
    });

    test('deleteProvider() sends DELETE to the provider', () async {
      final mockClient = MockSupabaseHttpClient()..stub(_providerJson());

      await clientWith(mockClient).admin.sso.deleteProvider(_providerId);

      expect(
        mockClient.requestsTo(
          '/admin/sso/providers/$_providerId',
          method: HttpMethod.delete,
        ),
        hasLength(1),
      );
    });
  });
}
