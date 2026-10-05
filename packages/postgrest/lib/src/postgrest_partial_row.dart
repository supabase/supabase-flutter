part of 'postgrest_typed_builder.dart';

/// Something a value can be read for from a [PostgrestPartialRow] of [Row]:
/// a stored column, a derived expression, or a relation.
///
/// [Output] is what the read produces: [PostgrestColumn] reads its value type,
/// [PostgrestNullableColumn], [PostgrestDerivedExpression] and
/// [PostgrestJsonPath] the nullable form of theirs, a
/// [PostgrestToOneRelation] a nullable nested [PostgrestPartialRow] and a
/// [PostgrestToManyRelation] a list of them.
@experimental
sealed class PostgrestReadable<Row, Output> {
  /// The key the value comes back under in a response row.
  String get responseKey;

  /// [json], the decoded value under [responseKey], as [Output]. [nested]
  /// is what the `select` list asked for under the key, which shapes the
  /// partial rows of an embed.
  Output _read(Object? json, _NestedSelection nested);

  /// Whether a `*` in the `select` list covers this: it does a stored
  /// column, and neither a relation nor a derived expression.
  bool get _selectedByStar;
}

/// A row of a `select` list, as returned by
/// [PostgrestTypedQueryBuilder.selectOnly] and
/// [PostgrestTypedTransformBuilder.selectOnly].
///
/// Values are read through the entries of the list, so the entry's type
/// types the read and an entry of another table does not compile:
///
/// ```dart
/// final books = await client
///     .table(Books.table)
///     .selectOnly([
///       Books.id,
///       Books.title,
///       Books.author.select([Authors.name]),
///     ]);
///
/// for (final book in books) {
///   final int id = book.read(Books.id);
///   final String? authorName = book.read(Books.author)?.read(Authors.name);
/// }
/// ```
///
/// Reading an entry the list did not ask for throws a [StateError] naming it,
/// instead of the null cast a getter of the full row type would fail with.
@experimental
final class PostgrestPartialRow<Row> {
  const PostgrestPartialRow._(
    this._json,
    this._selections, {
    required bool allColumns,
  }) : _allColumns = allColumns;

  final Map<String, dynamic> _json;

  /// The entries of the `select` list this row answers.
  final List<PostgrestSelectable<Object?>> _selections;

  /// Whether the list also asked for every column with `*`, so any column
  /// can be read, though still no relation.
  final bool _allColumns;

  /// A row of [selections] decoded from [json] that reached the client some
  /// other way than a PostgREST response, such as a realtime change payload.
  @internal
  static PostgrestPartialRow<Row> fromSelections<Row>(
    Map<String, dynamic> json,
    List<PostgrestSelectable<Row>> selections,
  ) => PostgrestPartialRow._(json, selections, allColumns: false);

  /// The value of [entry] in this row.
  ///
  /// A stored column reads as its value type, nullable when the database
  /// allows `NULL`; a derived expression and a JSON path as nullable; a
  /// relation as its embedded partial rows. An entry of an embedded table
  /// is read from the nested row:
  /// `book.read(Books.author)?.read(Authors.name)`.
  ///
  /// Throws a [StateError] when the `select` list did not ask for [entry],
  /// and a [TypeError] when the response holds a value of another type than
  /// the entry declares.
  Output read<Output>(PostgrestReadable<Row, Output> entry) {
    final nested = _nestedSelection(entry);
    if (nested == null) {
      throw StateError(
        '`${entry.responseKey}` was not selected. The row holds '
        '${_describeKeys()}.',
      );
    }
    return entry._read(_json[entry.responseKey], nested);
  }

  /// What the `select` list asked for under the key of [entry], or `null`
  /// when nothing.
  ///
  /// `*` covers every stored column and nothing else: no relation, and no
  /// derived expression either.
  _NestedSelection? _nestedSelection(PostgrestReadable<Row, Object?> entry) {
    var found = false;
    var allColumns = false;
    final selections = <PostgrestSelectable<Object?>>[];
    for (final selection in _selections) {
      if (selection.responseKey != entry.responseKey) continue;
      found = true;
      if (selection case _Embedded(_selections: final members)) {
        if (members.isEmpty) {
          allColumns = true;
        } else {
          selections.addAll(members);
        }
      }
    }
    if (found) return _NestedSelection(selections, allColumns: allColumns);
    if (_allColumns && entry._selectedByStar) {
      return const _NestedSelection([], allColumns: false);
    }
    return null;
  }

  String _describeKeys() {
    final keys = <String>{
      if (_allColumns) 'every column',
      for (final selection in _selections) '`${selection.responseKey}`',
    };
    return keys.isEmpty ? 'nothing' : keys.join(', ');
  }

  /// The row as decoded from the response.
  Map<String, dynamic> toJson() => _json;

  @override
  String toString() => 'PostgrestPartialRow($_json)';
}

/// What a `select` list asked for under one response key.
final class _NestedSelection {
  const _NestedSelection(this.selections, {required this.allColumns});

  /// The entries asked for of the embedded table, merged over every entry of
  /// the relation in the list.
  final List<PostgrestSelectable<Object?>> selections;

  /// Whether an entry asked for every column of the embedded table.
  final bool allColumns;
}

/// The error for reading an embedded entry directly instead of through its
/// relation.
UnsupportedError _embeddedReadError(
  PostgrestRelation<Object?, Object?> relation,
) => UnsupportedError(
  'An entry of the `${relation.key}` embed is read from the nested row: '
  'read the relation first, then the entry from its result.',
);
