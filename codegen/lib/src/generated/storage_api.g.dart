// GENERATED CODE - DO NOT MODIFY BY HAND.
// Generated from openapi/StorageService.openapi.json by bin/generate.dart.
// ignore_for_file: prefer_final_locals

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../runtime.dart';

class Bucket {
  Bucket({
    required this.id,
    required this.name,
    required this.public,
    this.fileSizeLimit,
    this.allowedMimeTypes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final bool public;
  final num? fileSizeLimit;
  final List<String>? allowedMimeTypes;
  final String? createdAt;
  final String? updatedAt;

  factory Bucket.fromJson(Map<String, dynamic> json) => Bucket(
        id: json['id'] as String,
        name: json['name'] as String,
        public: json['public'] as bool,
        fileSizeLimit: json['file_size_limit'] as num?,
        allowedMimeTypes: json['allowed_mime_types'] == null
            ? null
            : (json['allowed_mime_types'] as List).cast<String>(),
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'public': public,
        if (fileSizeLimit != null) 'file_size_limit': fileSizeLimit,
        if (allowedMimeTypes != null) 'allowed_mime_types': allowedMimeTypes,
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
}

class CopyObjectRequestContent {
  CopyObjectRequestContent({
    required this.bucketId,
    required this.sourceKey,
    required this.destinationKey,
    this.destinationBucket,
  });

  final String bucketId;
  final String sourceKey;
  final String destinationKey;
  final String? destinationBucket;

  factory CopyObjectRequestContent.fromJson(Map<String, dynamic> json) =>
      CopyObjectRequestContent(
        bucketId: json['bucketId'] as String,
        sourceKey: json['sourceKey'] as String,
        destinationKey: json['destinationKey'] as String,
        destinationBucket: json['destinationBucket'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'bucketId': bucketId,
        'sourceKey': sourceKey,
        'destinationKey': destinationKey,
        if (destinationBucket != null) 'destinationBucket': destinationBucket,
      };
}

class CopyObjectResponseContent {
  CopyObjectResponseContent({
    required this.key,
  });

  final String key;

  factory CopyObjectResponseContent.fromJson(Map<String, dynamic> json) =>
      CopyObjectResponseContent(
        key: json['Key'] as String,
      );

  Map<String, dynamic> toJson() => {
        'Key': key,
      };
}

class CreateBucketRequestContent {
  CreateBucketRequestContent({
    required this.id,
    required this.name,
    required this.public,
    this.fileSizeLimit,
    this.allowedMimeTypes,
  });

  final String id;
  final String name;
  final bool public;
  final num? fileSizeLimit;
  final List<String>? allowedMimeTypes;

  factory CreateBucketRequestContent.fromJson(Map<String, dynamic> json) =>
      CreateBucketRequestContent(
        id: json['id'] as String,
        name: json['name'] as String,
        public: json['public'] as bool,
        fileSizeLimit: json['file_size_limit'] as num?,
        allowedMimeTypes: json['allowed_mime_types'] == null
            ? null
            : (json['allowed_mime_types'] as List).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'public': public,
        if (fileSizeLimit != null) 'file_size_limit': fileSizeLimit,
        if (allowedMimeTypes != null) 'allowed_mime_types': allowedMimeTypes,
      };
}

class CreateSignedUploadUrlResponseContent {
  CreateSignedUploadUrlResponseContent({
    required this.url,
  });

  final String url;

  factory CreateSignedUploadUrlResponseContent.fromJson(
          Map<String, dynamic> json) =>
      CreateSignedUploadUrlResponseContent(
        url: json['url'] as String,
      );

  Map<String, dynamic> toJson() => {
        'url': url,
      };
}

class CreateSignedUrlRequestContent {
  CreateSignedUrlRequestContent({
    required this.expiresIn,
  });

  final num expiresIn;

  factory CreateSignedUrlRequestContent.fromJson(Map<String, dynamic> json) =>
      CreateSignedUrlRequestContent(
        expiresIn: json['expiresIn'] as num,
      );

  Map<String, dynamic> toJson() => {
        'expiresIn': expiresIn,
      };
}

class CreateSignedUrlResponseContent {
  CreateSignedUrlResponseContent({
    required this.signedURL,
  });

  final String signedURL;

  factory CreateSignedUrlResponseContent.fromJson(Map<String, dynamic> json) =>
      CreateSignedUrlResponseContent(
        signedURL: json['signedURL'] as String,
      );

  Map<String, dynamic> toJson() => {
        'signedURL': signedURL,
      };
}

class CreateSignedUrlsRequestContent {
  CreateSignedUrlsRequestContent({
    required this.expiresIn,
    required this.paths,
  });

  final num expiresIn;
  final List<String> paths;

  factory CreateSignedUrlsRequestContent.fromJson(Map<String, dynamic> json) =>
      CreateSignedUrlsRequestContent(
        expiresIn: json['expiresIn'] as num,
        paths: (json['paths'] as List).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'expiresIn': expiresIn,
        'paths': paths,
      };
}

class CreateSignedUrlsResponseContent {
  CreateSignedUrlsResponseContent({
    required this.items,
  });

  final List<SignedUrlResult> items;

  factory CreateSignedUrlsResponseContent.fromJson(Map<String, dynamic> json) =>
      CreateSignedUrlsResponseContent(
        items: (json['items'] as List)
            .map((e) => SignedUrlResult.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class DeleteObjectsRequestContent {
  DeleteObjectsRequestContent({
    required this.prefixes,
  });

  final List<String> prefixes;

  factory DeleteObjectsRequestContent.fromJson(Map<String, dynamic> json) =>
      DeleteObjectsRequestContent(
        prefixes: (json['prefixes'] as List).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'prefixes': prefixes,
      };
}

class DeleteObjectsResponseContent {
  DeleteObjectsResponseContent({
    required this.items,
  });

  final List<FileObject> items;

  factory DeleteObjectsResponseContent.fromJson(Map<String, dynamic> json) =>
      DeleteObjectsResponseContent(
        items: (json['items'] as List)
            .map((e) => FileObject.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class FileMetadata {
  FileMetadata({
    this.eTag,
    this.size,
    this.mimetype,
    this.cacheControl,
    this.lastModified,
    this.contentLength,
    this.httpStatusCode,
  });

  final String? eTag;
  final num? size;
  final String? mimetype;
  final String? cacheControl;
  final String? lastModified;
  final num? contentLength;
  final num? httpStatusCode;

  factory FileMetadata.fromJson(Map<String, dynamic> json) => FileMetadata(
        eTag: json['eTag'] as String?,
        size: json['size'] as num?,
        mimetype: json['mimetype'] as String?,
        cacheControl: json['cacheControl'] as String?,
        lastModified: json['lastModified'] as String?,
        contentLength: json['contentLength'] as num?,
        httpStatusCode: json['httpStatusCode'] as num?,
      );

  Map<String, dynamic> toJson() => {
        if (eTag != null) 'eTag': eTag,
        if (size != null) 'size': size,
        if (mimetype != null) 'mimetype': mimetype,
        if (cacheControl != null) 'cacheControl': cacheControl,
        if (lastModified != null) 'lastModified': lastModified,
        if (contentLength != null) 'contentLength': contentLength,
        if (httpStatusCode != null) 'httpStatusCode': httpStatusCode,
      };
}

class FileObject {
  FileObject({
    required this.name,
    this.id,
    this.updatedAt,
    this.createdAt,
    this.lastAccessedAt,
    this.metadata,
  });

  final String name;
  final String? id;
  final String? updatedAt;
  final String? createdAt;
  final String? lastAccessedAt;
  final FileMetadata? metadata;

  factory FileObject.fromJson(Map<String, dynamic> json) => FileObject(
        name: json['name'] as String,
        id: json['id'] as String?,
        updatedAt: json['updated_at'] as String?,
        createdAt: json['created_at'] as String?,
        lastAccessedAt: json['last_accessed_at'] as String?,
        metadata: json['metadata'] == null
            ? null
            : FileMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (id != null) 'id': id,
        if (updatedAt != null) 'updated_at': updatedAt,
        if (createdAt != null) 'created_at': createdAt,
        if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
        if (metadata != null) 'metadata': metadata!.toJson(),
      };
}

class GetBucketResponseContent {
  GetBucketResponseContent({
    required this.id,
    required this.name,
    required this.public,
    this.fileSizeLimit,
    this.allowedMimeTypes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final bool public;
  final num? fileSizeLimit;
  final List<String>? allowedMimeTypes;
  final String? createdAt;
  final String? updatedAt;

  factory GetBucketResponseContent.fromJson(Map<String, dynamic> json) =>
      GetBucketResponseContent(
        id: json['id'] as String,
        name: json['name'] as String,
        public: json['public'] as bool,
        fileSizeLimit: json['file_size_limit'] as num?,
        allowedMimeTypes: json['allowed_mime_types'] == null
            ? null
            : (json['allowed_mime_types'] as List).cast<String>(),
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'public': public,
        if (fileSizeLimit != null) 'file_size_limit': fileSizeLimit,
        if (allowedMimeTypes != null) 'allowed_mime_types': allowedMimeTypes,
        if (createdAt != null) 'created_at': createdAt,
        if (updatedAt != null) 'updated_at': updatedAt,
      };
}

class GetObjectInfoResponseContent {
  GetObjectInfoResponseContent({
    this.eTag,
    this.size,
    this.mimetype,
    this.cacheControl,
    this.lastModified,
    this.contentLength,
    this.httpStatusCode,
  });

  final String? eTag;
  final num? size;
  final String? mimetype;
  final String? cacheControl;
  final String? lastModified;
  final num? contentLength;
  final num? httpStatusCode;

  factory GetObjectInfoResponseContent.fromJson(Map<String, dynamic> json) =>
      GetObjectInfoResponseContent(
        eTag: json['eTag'] as String?,
        size: json['size'] as num?,
        mimetype: json['mimetype'] as String?,
        cacheControl: json['cacheControl'] as String?,
        lastModified: json['lastModified'] as String?,
        contentLength: json['contentLength'] as num?,
        httpStatusCode: json['httpStatusCode'] as num?,
      );

  Map<String, dynamic> toJson() => {
        if (eTag != null) 'eTag': eTag,
        if (size != null) 'size': size,
        if (mimetype != null) 'mimetype': mimetype,
        if (cacheControl != null) 'cacheControl': cacheControl,
        if (lastModified != null) 'lastModified': lastModified,
        if (contentLength != null) 'contentLength': contentLength,
        if (httpStatusCode != null) 'httpStatusCode': httpStatusCode,
      };
}

class ListBucketsResponseContent {
  ListBucketsResponseContent({
    required this.items,
  });

  final List<Bucket> items;

  factory ListBucketsResponseContent.fromJson(Map<String, dynamic> json) =>
      ListBucketsResponseContent(
        items: (json['items'] as List)
            .map((e) => Bucket.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class ListObjectsRequestContent {
  ListObjectsRequestContent({
    required this.prefix,
    this.limit,
    this.offset,
    this.sortBy,
  });

  final String prefix;
  final num? limit;
  final num? offset;
  final SortBy? sortBy;

  factory ListObjectsRequestContent.fromJson(Map<String, dynamic> json) =>
      ListObjectsRequestContent(
        prefix: json['prefix'] as String,
        limit: json['limit'] as num?,
        offset: json['offset'] as num?,
        sortBy: json['sortBy'] == null
            ? null
            : SortBy.fromJson(json['sortBy'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'prefix': prefix,
        if (limit != null) 'limit': limit,
        if (offset != null) 'offset': offset,
        if (sortBy != null) 'sortBy': sortBy!.toJson(),
      };
}

class ListObjectsResponseContent {
  ListObjectsResponseContent({
    required this.items,
  });

  final List<FileObject> items;

  factory ListObjectsResponseContent.fromJson(Map<String, dynamic> json) =>
      ListObjectsResponseContent(
        items: (json['items'] as List)
            .map((e) => FileObject.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class MoveObjectRequestContent {
  MoveObjectRequestContent({
    required this.bucketId,
    required this.sourceKey,
    required this.destinationKey,
    this.destinationBucket,
  });

  final String bucketId;
  final String sourceKey;
  final String destinationKey;
  final String? destinationBucket;

  factory MoveObjectRequestContent.fromJson(Map<String, dynamic> json) =>
      MoveObjectRequestContent(
        bucketId: json['bucketId'] as String,
        sourceKey: json['sourceKey'] as String,
        destinationKey: json['destinationKey'] as String,
        destinationBucket: json['destinationBucket'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'bucketId': bucketId,
        'sourceKey': sourceKey,
        'destinationKey': destinationKey,
        if (destinationBucket != null) 'destinationBucket': destinationBucket,
      };
}

class SignedUrlResult {
  SignedUrlResult({
    this.signedURL,
    required this.path,
    this.error,
  });

  final String? signedURL;
  final String path;
  final String? error;

  factory SignedUrlResult.fromJson(Map<String, dynamic> json) =>
      SignedUrlResult(
        signedURL: json['signedURL'] as String?,
        path: json['path'] as String,
        error: json['error'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (signedURL != null) 'signedURL': signedURL,
        'path': path,
        if (error != null) 'error': error,
      };
}

class SortBy {
  SortBy({
    this.column,
    this.order,
  });

  final String? column;
  final String? order;

  factory SortBy.fromJson(Map<String, dynamic> json) => SortBy(
        column: json['column'] as String?,
        order: json['order'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (column != null) 'column': column,
        if (order != null) 'order': order,
      };
}

class StorageErrorResponseContent {
  StorageErrorResponseContent({
    this.message,
    this.error,
    this.statusCode,
  });

  final String? message;
  final String? error;
  final String? statusCode;

  factory StorageErrorResponseContent.fromJson(Map<String, dynamic> json) =>
      StorageErrorResponseContent(
        message: json['message'] as String?,
        error: json['error'] as String?,
        statusCode: json['statusCode'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (message != null) 'message': message,
        if (error != null) 'error': error,
        if (statusCode != null) 'statusCode': statusCode,
      };
}

class UpdateBucketRequestContent {
  UpdateBucketRequestContent({
    required this.public,
    this.fileSizeLimit,
    this.allowedMimeTypes,
  });

  final bool public;
  final num? fileSizeLimit;
  final List<String>? allowedMimeTypes;

  factory UpdateBucketRequestContent.fromJson(Map<String, dynamic> json) =>
      UpdateBucketRequestContent(
        public: json['public'] as bool,
        fileSizeLimit: json['file_size_limit'] as num?,
        allowedMimeTypes: json['allowed_mime_types'] == null
            ? null
            : (json['allowed_mime_types'] as List).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'public': public,
        if (fileSizeLimit != null) 'file_size_limit': fileSizeLimit,
        if (allowedMimeTypes != null) 'allowed_mime_types': allowedMimeTypes,
      };
}

class FileUploadedResponse {
  FileUploadedResponse({
    required this.key,
    required this.id,
  });

  final String key;
  final String id;

  factory FileUploadedResponse.fromJson(Map<String, dynamic> json) =>
      FileUploadedResponse(
        key: json['Key'] as String,
        id: json['Id'] as String,
      );

  Map<String, dynamic> toJson() => {
        'Key': key,
        'Id': id,
      };
}

/// Generated HTTP client. Every operation goes through the
/// hand-written [ApiClient] runtime for headers and transport.
class StorageApi {
  StorageApi(this._client);

  final ApiClient _client;

  Future<ListBucketsResponseContent> listBuckets() async {
    final uri = _client.uri('/bucket');
    final headers = await _client.headers({});
    final request = http.Request('GET', uri);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return ListBucketsResponseContent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> createBucket({required CreateBucketRequestContent body}) async {
    final uri = _client.uri('/bucket');
    final headers = await _client.headers({});
    final request = http.Request('POST', uri)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body.toJson());
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    await readOrThrow(streamed);
  }

  Future<void> deleteBucket({required String id}) async {
    final uri = _client.uri('/bucket/${id}');
    final headers = await _client.headers({});
    final request = http.Request('DELETE', uri);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    await readOrThrow(streamed);
  }

  Future<GetBucketResponseContent> getBucket({required String id}) async {
    final uri = _client.uri('/bucket/${id}');
    final headers = await _client.headers({});
    final request = http.Request('GET', uri);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return GetBucketResponseContent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> updateBucket(
      {required String id, required UpdateBucketRequestContent body}) async {
    final uri = _client.uri('/bucket/${id}');
    final headers = await _client.headers({});
    final request = http.Request('PUT', uri)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body.toJson());
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    await readOrThrow(streamed);
  }

  Future<void> emptyBucket({required String id}) async {
    final uri = _client.uri('/bucket/${id}/empty');
    final headers = await _client.headers({});
    final request = http.Request('POST', uri);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    await readOrThrow(streamed);
  }

  Future<CopyObjectResponseContent> copyObject(
      {required CopyObjectRequestContent body}) async {
    final uri = _client.uri('/object/copy');
    final headers = await _client.headers({});
    final request = http.Request('POST', uri)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body.toJson());
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return CopyObjectResponseContent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<GetObjectInfoResponseContent> getObjectInfo(
      {required String bucketId, required String wildcardPath}) async {
    final uri = _client.uri('/object/info/${bucketId}/${wildcardPath}');
    final headers = await _client.headers({});
    final request = http.Request('GET', uri);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return GetObjectInfoResponseContent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ListObjectsResponseContent> listObjects(
      {required String bucketId,
      required ListObjectsRequestContent body}) async {
    final uri = _client.uri('/object/list/${bucketId}');
    final headers = await _client.headers({});
    final request = http.Request('POST', uri)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body.toJson());
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return ListObjectsResponseContent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> moveObject({required MoveObjectRequestContent body}) async {
    final uri = _client.uri('/object/move');
    final headers = await _client.headers({});
    final request = http.Request('POST', uri)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body.toJson());
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    await readOrThrow(streamed);
  }

  Future<CreateSignedUrlsResponseContent> createSignedUrls(
      {required String bucketId,
      required CreateSignedUrlsRequestContent body}) async {
    final uri = _client.uri('/object/sign/${bucketId}');
    final headers = await _client.headers({});
    final request = http.Request('POST', uri)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body.toJson());
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return CreateSignedUrlsResponseContent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CreateSignedUrlResponseContent> createSignedUrl(
      {required String bucketId,
      required String wildcardPath,
      required CreateSignedUrlRequestContent body}) async {
    final uri = _client.uri('/object/sign/${bucketId}/${wildcardPath}');
    final headers = await _client.headers({});
    final request = http.Request('POST', uri)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body.toJson());
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return CreateSignedUrlResponseContent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<CreateSignedUploadUrlResponseContent> createSignedUploadUrl(
      {required String bucketId,
      required String wildcardPath,
      String? xUpsert}) async {
    final uri = _client.uri('/object/upload/sign/${bucketId}/${wildcardPath}');
    final headers = await _client.headers({
      if (xUpsert != null) 'x-upsert': xUpsert,
    });
    final request = http.Request('POST', uri);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return CreateSignedUploadUrlResponseContent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<DeleteObjectsResponseContent> deleteObjects(
      {required String bucketId,
      required DeleteObjectsRequestContent body}) async {
    final uri = _client.uri('/object/${bucketId}');
    final headers = await _client.headers({});
    final request = http.Request('DELETE', uri)
      ..headers['content-type'] = 'application/json'
      ..body = jsonEncode(body.toJson());
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return DeleteObjectsResponseContent.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> headObject(
      {required String bucketId, required String wildcardPath}) async {
    final uri = _client.uri('/object/${bucketId}/${wildcardPath}');
    final headers = await _client.headers({});
    final request = http.Request('HEAD', uri);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    await readOrThrow(streamed);
  }

  Future<FileUploadedResponse> uploadObject(
      {required String bucketId,
      required String wildcardPath,
      String? xUpsert,
      required Stream<List<int>> file,
      required int fileLength,
      String? cacheControl,
      Map<String, dynamic>? metadata,
      String? fileName}) async {
    final uri = _client.uri('/object/${bucketId}/${wildcardPath}');
    final headers = await _client.headers({
      if (xUpsert != null) 'x-upsert': xUpsert,
    });
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile(
      'file',
      file,
      fileLength,
      filename: fileName,
    ));
    if (cacheControl != null) request.fields['cacheControl'] = cacheControl;
    if (metadata != null) request.fields['metadata'] = jsonEncode(metadata);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return FileUploadedResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<FileUploadedResponse> updateObject(
      {required String bucketId,
      required String wildcardPath,
      required Stream<List<int>> file,
      required int fileLength,
      String? cacheControl,
      Map<String, dynamic>? metadata,
      String? fileName}) async {
    final uri = _client.uri('/object/${bucketId}/${wildcardPath}');
    final headers = await _client.headers({});
    final request = http.MultipartRequest('PUT', uri);
    request.files.add(http.MultipartFile(
      'file',
      file,
      fileLength,
      filename: fileName,
    ));
    if (cacheControl != null) request.fields['cacheControl'] = cacheControl;
    if (metadata != null) request.fields['metadata'] = jsonEncode(metadata);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return FileUploadedResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createTusUpload(
      {required String tusResumable,
      required int uploadLength,
      required String uploadMetadata,
      String? xUpsert}) async {
    final uri = _client.uri('/upload/resumable');
    final headers = await _client.headers({
      'Tus-Resumable': tusResumable,
      'Upload-Length': '$uploadLength',
      'Upload-Metadata': uploadMetadata,
      if (xUpsert != null) 'x-upsert': xUpsert,
    });
    final request = http.Request('POST', uri);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return {
      'location': response.headers['location'],
    };
  }

  Future<Map<String, dynamic>> getUploadOffset(
      {required String uploadId, required String tusResumable}) async {
    final uri = _client.uri('/upload/resumable/${uploadId}');
    final headers = await _client.headers({
      'Tus-Resumable': tusResumable,
    });
    final request = http.Request('HEAD', uri);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return {
      'uploadOffset': int.parse(response.headers['upload-offset']!),
    };
  }

  Future<Map<String, dynamic>> uploadChunk(
      {required String uploadId,
      required String tusResumable,
      required int uploadOffset,
      required Stream<List<int>> body,
      int? contentLength}) async {
    final uri = _client.uri('/upload/resumable/${uploadId}');
    final headers = await _client.headers({
      'Tus-Resumable': tusResumable,
      'Upload-Offset': '$uploadOffset',
    });
    final request = streamingRequest('PATCH', uri,
        body: body, contentLength: contentLength);
    request.headers.addAll(headers);
    final streamed = await _client.send(request);
    final response = await readOrThrow(streamed);
    return {
      'uploadOffset': int.parse(response.headers['upload-offset']!),
    };
  }
}
