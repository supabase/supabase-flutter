import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart' show hex;
import 'package:meta/meta.dart';
import 'package:postgrest/postgrest.dart';
import 'package:supabase_common/supabase_common.dart' show SortDirection;

part 'postgrest_bytea.dart';
part 'postgrest_column_expression.dart';
part 'postgrest_date.dart';
part 'postgrest_derived_expression.dart';
part 'postgrest_embedded_relation.dart';
part 'postgrest_filter.dart';
part 'postgrest_filter_operators.dart';
part 'postgrest_interval.dart';
part 'postgrest_ordering.dart';
part 'postgrest_partial_row.dart';
part 'postgrest_range.dart';
part 'postgrest_table.dart';
part 'postgrest_table_executor.dart';
part 'postgrest_table_request.dart';
part 'postgrest_time.dart';
part 'postgrest_typed_query_builder.dart';
part 'postgrest_typed_transform_builder.dart';
part 'postgrest_typed_filter_builder.dart';
part 'postgrest_typed_unscoped_builder.dart';
part 'postgrest_vector.dart';

List<Row> _rowsFromJson<Row>(
  RowConverter<Row> rowFromJson,
  PostgrestList rows,
) => [for (final row in rows) rowFromJson(row)];

/// The `select` parameter for [selections], or `*` when none are given.
///
/// Entries that go through the same relation are merged into one embed at
/// the position of the first, so `author(id),author(name)` is sent as
/// `author(id,name)`, since PostgREST joins a relation once per embed and
/// rejects a repeated join. Merging recurses into nested embeds, and an
/// entry that renders the same as an earlier one is left out.
String _selectList(List<PostgrestSelectable<Object?>> selections) {
  if (selections.isEmpty) return '*';
  if (selections case [final single]) return single.expression;
  final entries = <String>[];
  final embeds = <String, _EmbedGroup>{};
  for (final selection in selections) {
    if (selection case _Embedded(:final relation, _selections: final members)) {
      embeds
          .putIfAbsent(relation._selectName, () {
            entries.add('');
            return _EmbedGroup(entries.length - 1);
          })
          .add(members);
    } else {
      final expression = selection.expression;
      if (!entries.contains(expression)) entries.add(expression);
    }
  }
  for (final MapEntry(key: name, value: group) in embeds.entries) {
    entries[group.index] = group.render(name);
  }
  return entries.join(',');
}

/// The entries of one relation collected from a `select` list.
final class _EmbedGroup {
  _EmbedGroup(this.index);

  /// Where in the rendered list the embed goes: the position of its first
  /// entry.
  final int index;

  final List<PostgrestSelectable<Object?>> _members = [];

  /// Whether an entry asked for every column of the embed.
  bool _all = false;

  /// Adds the members of one entry; none means every column.
  void add(List<PostgrestSelectable<Object?>> members) {
    if (members.isEmpty) {
      _all = true;
    } else {
      _members.addAll(members);
    }
  }

  /// `name(*)`, `name(a,b)` or, when both were asked for, `name(*,a)`.
  String render(String name) {
    if (!_all) return _embedExpression(name, _members);
    final rest = _members.isEmpty ? '' : ',${_selectList(_members)}';
    return '$name(*$rest)';
  }
}

/// The `select` list form of an embed: [name] wrapping [members], or
/// `name(*)` when there are none.
String _embedExpression(
  String name,
  List<PostgrestSelectable<Object?>> members,
) => '$name(${_selectList(members)})';

/// [selections] as the request stores them: every column when none are
/// given. An empty list is rejected up front, naming the caller's
/// [parameter], so the error surfaces where `select` is called rather than
/// when awaited.
List<PostgrestSelectable<Row>> _checkedSelections<Row>(
  List<PostgrestSelectable<Row>>? selections,
  String parameter,
) {
  if (selections == null) return const [];
  if (selections.isEmpty) {
    throw ArgumentError.value(
      selections,
      parameter,
      'select needs at least one column',
    );
  }
  return selections;
}

/// The per-request options the typed builders set, see
/// [PostgrestRequestOptions].
extension on PostgrestRequestOptions {
  PostgrestRequestOptions _retry(bool enabled, int? count) =>
      copyWith(retryEnabled: enabled, retryCount: count);

  PostgrestRequestOptions _requestTimeout(Duration timeout) =>
      copyWith(requestTimeout: timeout);

  PostgrestRequestOptions _abortSignal(Future<void> abortSignal) =>
      copyWith(abortSignal: abortSignal);

  PostgrestRequestOptions _header(String key, String value) =>
      copyWith(headers: {...headers, key: value});
}

extension on PostgrestTableRequest {
  PostgrestTableRequest _retry(bool enabled, int? count) =>
      copyWith(options: options._retry(enabled, count));

  PostgrestTableRequest _requestTimeout(Duration timeout) =>
      copyWith(options: options._requestTimeout(timeout));

  PostgrestTableRequest _abortSignal(Future<void> abortSignal) =>
      copyWith(options: options._abortSignal(abortSignal));

  PostgrestTableRequest _header(String key, String value) =>
      copyWith(options: options._header(key, value));
}

/// Converts the result of a [PostgrestTableRequest] into [T].
typedef _ResultConverter<T> = T Function(PostgrestTableResult result);

_ResultConverter<List<Row>> _rowsConverter<Row>(
  RowConverter<Row> rowFromJson,
) =>
    (result) => _rowsFromJson(rowFromJson, result.data! as PostgrestList);

/// Converts the rows of a result into partial rows answering [selections].
_ResultConverter<List<PostgrestPartialRow<Row>>> _partialRowsConverter<Row>(
  List<PostgrestSelectable<Row>> selections,
) =>
    (result) => [
      for (final row in result.data! as PostgrestList)
        PostgrestPartialRow<Row>._(row, selections, allColumns: false),
    ];

void _noResult(PostgrestTableResult result) {}

/// The single-row shapes of a builder that resolves to a list of rows, the
/// full [Row] of a `select()` or the [PostgrestPartialRow] of a `selectOnly`.
///
/// They live on the list-shaped builders only, so a mutation without a
/// trailing `select`, which returns no rows, has no `single()` to call.
@experimental
extension PostgrestTypedRowsBuilder<Row, Element>
    on PostgrestTypedTransformBuilder<Row, List<Element>> {
  /// Retrieves only one row from the result.
  ///
  /// The result must be exactly one row, otherwise this will result in an
  /// error.
  ///
  /// ```dart
  /// final Book book = await client
  ///     .table(Books.table)
  ///     .select()
  ///     .where(Books.id.eq(1))
  ///     .single();
  /// ```
  PostgrestTypedTransformBuilder<Row, Element> single() => _shaped(
    PostgrestResultShape.single,
    (result) => _convertRow(result).single,
  );

  /// Retrieves at most one row from the result, or `null` when the result is
  /// empty.
  PostgrestTypedTransformBuilder<Row, Element?> maybeSingle() => _shaped(
    PostgrestResultShape.maybeSingle,
    (result) => result.data == null ? null : _convertRow(result).single,
  );

  /// Converts the one row of [result] the way the list conversion would,
  /// so the same element type comes out of both.
  List<Element> _convertRow(PostgrestTableResult result) => _convert(
    PostgrestTableResult(
      data: <PostgrestMap>[result.data! as PostgrestMap],
      count: result.count,
    ),
  );
}

/// A typed PostgREST request that can be awaited.
///
/// Holds the [request] the builder methods have collected so far and the
/// [PostgrestTableExecutor] that runs it. Awaiting the builder executes the
/// request and converts the result into [T], so awaiting it never exposes raw
/// `Map<String, dynamic>` data.
@experimental
class PostgrestTypedBuilder<T> implements Future<T> {
  const PostgrestTypedBuilder._(this.request, this._executor, this._convert);

  /// The request awaiting this builder executes.
  final PostgrestTableRequest request;

  final PostgrestTableExecutor _executor;
  final _ResultConverter<T> _convert;

  /// Runs [request] on the executor, routing a synchronous throw into the
  /// returned future so the [Future] contract holds for every executor.
  Future<T> _execute() =>
      Future.sync(() => _executor.execute(request)).then(_convert);

  PostgrestTypedBuilder<T> _with(PostgrestTableRequest changed) =>
      PostgrestTypedBuilder._(changed, _executor, _convert);

  /// Overrides the retry behavior for this request.
  ///
  /// See [PostgrestBuilder.retry] for [enabled] and [count].
  PostgrestTypedBuilder<T> retry({bool enabled = true, int? count}) =>
      _with(request._retry(enabled, count));

  /// Bounds how long a single attempt of this request may take, overriding
  /// the timeout configured on [PostgrestClient].
  ///
  /// Unlike [timeout], which only stops waiting for the result, this cancels
  /// the attempt. See [PostgrestBuilder.requestTimeout].
  PostgrestTypedBuilder<T> requestTimeout(Duration timeout) =>
      _with(request._requestTimeout(timeout));

  /// Cancels the request when [abortSignal] completes, throwing a
  /// [RequestAbortedException] and stopping any retries.
  ///
  /// ```dart
  /// final abort = Completer<void>();
  /// final books = client
  ///     .table(Books.table)
  ///     .select()
  ///     .abortSignal(abort.future);
  /// ```
  ///
  /// See [PostgrestBuilder.abortSignal].
  PostgrestTypedBuilder<T> abortSignal(Future<void> abortSignal) =>
      _with(request._abortSignal(abortSignal));

  /// Sets [key] to [value] in the headers of this request.
  PostgrestTypedBuilder<T> setHeader(String key, String value) =>
      _with(request._header(key, value));

  /// A broadcast stream of the one result. The request runs when the first
  /// listener subscribes, so a listener added later still receives it.
  @override
  Stream<T> asStream() => _execute().asStream().asBroadcastStream();

  @override
  Future<T> catchError(Function onError, {bool Function(Object error)? test}) =>
      _execute().catchError(onError, test: test);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) => _execute().then(onValue, onError: onError);

  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      _execute().timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      _execute().whenComplete(action);
}
