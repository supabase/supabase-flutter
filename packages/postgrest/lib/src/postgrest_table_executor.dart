part of 'postgrest_typed_builder.dart';

/// Runs the requests of the typed table API.
///
/// [PostgrestClient.table] uses an [HttpTableExecutor] unless another one is
/// given. An executor that decorates another, to cache, queue or log
/// requests, holds the inner executor and forwards to it:
///
/// ```dart
/// final class LoggingExecutor implements PostgrestTableExecutor {
///   const LoggingExecutor(this.inner);
///   final PostgrestTableExecutor inner;
///
///   @override
///   Future<PostgrestTableResult> execute(PostgrestTableRequest request) {
///     print('${request.operation.name} ${request.table.name}');
///     return inner.execute(request);
///   }
/// }
/// ```
@experimental
abstract interface class PostgrestTableExecutor {
  /// Performs [request] and returns its result in the shape it asked for.
  Future<PostgrestTableResult> execute(PostgrestTableRequest request);
}

/// The executor that sends a request to PostgREST.
///
/// The request is rendered through the untyped builders of [client], so the
/// parameters and headers on the wire are the ones [PostgrestClient.from]
/// would have produced for the same query.
@experimental
final class HttpTableExecutor implements PostgrestTableExecutor {
  const HttpTableExecutor(this.client);

  /// The client whose transport, headers and options the request uses.
  final PostgrestClient client;

  @override
  Future<PostgrestTableResult> execute(PostgrestTableRequest request) async {
    // ignore: invalid_use_of_internal_member
    final query = client.fromInSchema(request.table.name, request.schema);

    if (request.operation == PostgrestTableOperation.count) {
      final counted = _applyFilter(
        query.count(request.countOption ?? CountOption.exact),
        request.filter,
      );
      return PostgrestTableResult(count: await counted);
    }

    final filtered = _applyFilter(_operation(query, request), request.filter);
    final terminal = _terminal(_transforms(filtered, request), request);

    final countOption = request.countOption;
    if (countOption != null) {
      final response = await terminal.count(countOption);
      return PostgrestTableResult(data: response.data, count: response.count);
    }
    return PostgrestTableResult(data: await terminal);
  }

  static PostgrestFilterBuilder<Object?> _operation(
    PostgrestQueryBuilder query,
    PostgrestTableRequest request,
  ) => switch (request.operation) {
    PostgrestTableOperation.select => query.select(
      _selectList(request.columns),
    ),
    PostgrestTableOperation.insert => query.insert(
      request.payload!,
      defaultToNull: request.defaultToNull,
    ),
    PostgrestTableOperation.upsert => query.upsert(
      request.payload!,
      onConflict: request.onConflict?.map((column) => column.name).join(','),
      ignoreDuplicates: request.ignoreDuplicates,
      defaultToNull: request.defaultToNull,
    ),
    PostgrestTableOperation.update => query.update(request.payload!),
    PostgrestTableOperation.delete => query.delete(),
    PostgrestTableOperation.count => throw StateError(
      'count is rendered before the other operations',
    ),
  };

  static PostgrestFilterBuilder<T> _applyFilter<T>(
    PostgrestFilterBuilder<T> builder,
    PostgrestFilter<Object?>? filter,
  ) {
    if (filter == null) return builder;
    var filtered = builder;
    for (final parameter in filter.queryParameters) {
      filtered = filtered.appendSearchParameter(parameter.key, parameter.value);
    }
    return filtered;
  }

  static PostgrestTransformBuilder<Object?> _transforms(
    PostgrestFilterBuilder<Object?> filtered,
    PostgrestTableRequest request,
  ) {
    PostgrestTransformBuilder<Object?> transformed = filtered;
    if (request.operation.isMutation && request.returnsRows) {
      transformed = transformed.select(_selectList(request.columns));
    }
    for (final ordering in request.orderings) {
      transformed = transformed.appendOrderKey(ordering.orderKey);
    }
    final limit = request.limit;
    final offset = request.offset;
    if (offset != null && limit != null) {
      transformed = transformed.range(offset, offset + limit - 1);
    } else if (limit != null) {
      transformed = transformed.limit(limit);
    }
    for (final page in request.embeddedPages) {
      final pageLimit = page.limit;
      final pageOffset = page.offset;
      if (pageOffset != null && pageLimit != null) {
        transformed = transformed.range(
          pageOffset,
          pageOffset + pageLimit - 1,
          referencedTable: page.referencedTable,
        );
      } else if (pageLimit != null) {
        transformed = transformed.limit(
          pageLimit,
          referencedTable: page.referencedTable,
        );
      }
    }
    if (request.stripNulls) transformed = transformed.stripNulls();
    if (request.dryRun) transformed = transformed.dryRun();
    final maxAffected = request.maxAffected;
    if (maxAffected != null) transformed = transformed.maxAffected(maxAffected);
    return transformed;
  }

  static PostgrestBuilder<Object?> _terminal(
    PostgrestTransformBuilder<Object?> transformed,
    PostgrestTableRequest request,
  ) => switch (request.shape) {
    PostgrestResultShape.rows || PostgrestResultShape.none => transformed,
    PostgrestResultShape.single => transformed.single(),
    PostgrestResultShape.maybeSingle => transformed.maybeSingle(),
    PostgrestResultShape.head => transformed.head(),
    PostgrestResultShape.csv => transformed.csv(),
    PostgrestResultShape.geojson => transformed.geojson(),
    PostgrestResultShape.explain => _explain(transformed, request),
  };

  static PostgrestBuilder<Object?> _explain(
    PostgrestTransformBuilder<Object?> transformed,
    PostgrestTableRequest request,
  ) {
    final options = request.explainOptions ?? const PostgrestExplainOptions();
    return transformed.explain(
      analyze: options.analyze,
      verbose: options.verbose,
      settings: options.settings,
      buffers: options.buffers,
      wal: options.wal,
      format: options.format,
    );
  }
}
