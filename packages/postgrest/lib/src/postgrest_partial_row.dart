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
/// `supabase_typegen` also generates an extension per table with a getter for
/// every column, computed field and relation, so the same reads are
/// `book.id` and `book.author?.name`.
///
/// Reading an entry the list did not ask for throws a [StateError] naming it,
/// instead of the null cast a getter of the full row type would fail with.
@experimental
final class PostgrestPartialRow<Row> {
  const PostgrestPartialRow._(
    this._json,
    this._selections, {
    required bool allColumns,
    bool presentColumns = false,
  }) : _allColumns = allColumns,
       _presentColumns = presentColumns;

  /// A row of [selections] decoded from [json], such as a test fixture or a
  /// row of a `selectOnly` with the same [selections] that was stored.
  ///
  /// It reads exactly like the row the query returns, so a mapping from a
  /// partial row can be shared between them and unit tested on its own:
  ///
  /// ```dart
  /// const List<PostgrestStoredColumn<Book, Object>> summary = [
  ///   Books.id,
  ///   Books.title,
  /// ];
  /// final book = PostgrestPartialRow<Book>.fromJson(
  ///   {'id': 1, 'title': 'Dune'},
  ///   summary,
  /// );
  /// final String title = book.read(Books.title);
  /// ```
  ///
  /// Throws an [ArgumentError] when [selections] is empty, when [json], or a
  /// row embedded in it, has no key for one of the entries, or when an embed
  /// holds something else than a row or `null` for a to-one relation and a
  /// list of rows for a to-many one. A response to the `select` list always
  /// holds every key, even when its value is `null`, while a missing key
  /// would otherwise read as `null` too. [PostgrestTable.allColumns] does not
  /// check which columns are present.
  factory PostgrestPartialRow.fromJson(
    Map<String, dynamic> json,
    List<PostgrestSelectable<Row>> selections,
  ) {
    if (selections.isEmpty) {
      throw ArgumentError.value(
        selections,
        'selections',
        'A partial row needs at least one entry',
      );
    }
    _checkKeys(json, selections, '');
    return fromSelections(json, selections);
  }

  final Map<String, dynamic> _json;

  /// The entries of the `select` list this row answers.
  final List<PostgrestSelectable<Object?>> _selections;

  /// Whether the list also asked for every column with `*`, so any column
  /// can be read, though still no relation.
  final bool _allColumns;

  /// Whether every stored column the row holds a value for can be read,
  /// because the row is not the answer to a `select` list.
  final bool _presentColumns;

  /// A row of [selections] decoded from [json] that reached the client some
  /// other way than a PostgREST response, such as a realtime change payload.
  @internal
  static PostgrestPartialRow<Row> fromSelections<Row>(
    Map<String, dynamic> json,
    List<PostgrestSelectable<Row>> selections,
  ) => PostgrestPartialRow._(
    json,
    selections,
    allColumns: _selectsAllColumns(selections),
  );

  /// A row holding whichever stored columns [json] has a value for, such as
  /// the old row of a realtime change payload, which carries the primary key
  /// only unless the table has `REPLICA IDENTITY FULL`.
  @internal
  static PostgrestPartialRow<Row> fromPresentColumns<Row>(
    Map<String, dynamic> json,
  ) => PostgrestPartialRow._(
    json,
    const [],
    allColumns: false,
    presentColumns: true,
  );

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
  ///
  /// A context type wins over [entry] when inferring [Output], so returned
  /// straight from an `async` function it becomes a `FutureOr`. A getter
  /// generated by `supabase_typegen` keeps the type of the column,
  /// `return book.id;`, and otherwise [Output] is passed explicitly:
  /// `return book.read<int>(Books.id);`.
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
        if (members.isEmpty || _selectsAllColumns(members)) allColumns = true;
        selections.addAll(members);
      }
    }
    if (found) return _NestedSelection(selections, allColumns: allColumns);
    final present = _presentColumns && _json.containsKey(entry.responseKey);
    if ((_allColumns || present) && entry._selectedByStar) {
      return const _NestedSelection([], allColumns: false);
    }
    return null;
  }

  String _describeKeys() {
    final keys = <String>{
      if (_allColumns) 'every column',
      if (_presentColumns)
        for (final key in _json.keys) '`$key`',
      for (final selection in _selections)
        if (selection is! PostgrestAllColumns) '`${selection.responseKey}`',
    };
    return keys.isEmpty ? 'nothing' : keys.join(', ');
  }

  /// The row as the full [Row] of [table], when the `select` list asked for
  /// every column with [PostgrestTable.allColumns] or the row is a whole
  /// embed.
  ///
  /// Throws a [StateError] when it did not, since [Row] would miss columns.
  Row toRow(PostgrestTable<Row, Object?, Object?> table) {
    if (!_allColumns) {
      throw StateError(
        'Only a row of every column converts into `$Row`. The row holds '
        '${_describeKeys()}.',
      );
    }
    return table.rowFromJson(_json);
  }

  /// The row as decoded from the response.
  Map<String, dynamic> toJson() => _json;

  @override
  String toString() => 'PostgrestPartialRow($_json)';
}

void _checkKeys(
  Map<String, dynamic> json,
  List<PostgrestSelectable<Object?>> selections,
  String path,
) {
  for (final selection in selections) {
    if (selection is PostgrestAllColumns) continue;
    final key = selection.responseKey;
    if (!json.containsKey(key)) {
      throw ArgumentError(
        'Has no `$path$key`, which the selections ask for',
        'json',
      );
    }
    if (selection case _Embedded(:final relation, _selections: final members)) {
      switch ((relation, json[key])) {
        case (PostgrestToOneRelation(), null):
          break;
        case (PostgrestToOneRelation(), final Map<String, dynamic> row):
          _checkKeys(row, members, '$path$key.');
        case (PostgrestToManyRelation(), final List<Object?> rows):
          for (final (index, row) in rows.indexed) {
            if (row is! Map<String, dynamic>) {
              throw ArgumentError(
                'Holds ${row.runtimeType} at `$path$key[$index]`, not a row',
                'json',
              );
            }
            _checkKeys(row, members, '$path$key[$index].');
          }
        case (PostgrestToOneRelation(), final value):
          throw ArgumentError(
            'Holds ${value.runtimeType} at `$path$key`, not a row or null',
            'json',
          );
        case (PostgrestToManyRelation(), final value):
          throw ArgumentError(
            'Holds ${value.runtimeType} at `$path$key`, not a list of rows',
            'json',
          );
      }
    }
  }
}

/// Whether [selections] ask for every column with [PostgrestAllColumns].
bool _selectsAllColumns(List<PostgrestSelectable<Object?>> selections) =>
    selections.any((selection) => selection is PostgrestAllColumns);

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
