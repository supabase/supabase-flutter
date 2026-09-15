import 'package:supabase_typegen/src/introspection/relationships.dart';
import 'package:test/test.dart';

const postsAuthorFk = <String, dynamic>{
  'foreign_key_name': 'posts_author_id_fkey',
  'schema': 'public',
  'relation': 'posts',
  'columns': ['author_id'],
  'is_one_to_one': false,
  'referenced_schema': 'public',
  'referenced_relation': 'users',
  'referenced_columns': ['id'],
};

const viewToTableDep = <String, dynamic>{
  'table_schema': 'public',
  'table_name': 'posts',
  'view_schema': 'public',
  'view_name': 'posts_view',
  'constraint_name': 'posts_author_id_fkey',
  'constraint_type': 'f',
  'column_dependencies': [
    {
      'table_column': 'author_id',
      'view_columns': ['author_id'],
    },
  ],
};

const tableToViewDep = <String, dynamic>{
  'table_schema': 'public',
  'table_name': 'users',
  'view_schema': 'public',
  'view_name': 'users_view',
  'constraint_name': 'posts_author_id_fkey',
  'constraint_type': 'f_ref',
  'column_dependencies': [
    {
      'table_column': 'id',
      'view_columns': ['id'],
    },
  ],
};

const postsViewToUsers = <String, dynamic>{
  'foreign_key_name': 'posts_author_id_fkey',
  'schema': 'public',
  'relation': 'posts_view',
  'columns': ['author_id'],
  'is_one_to_one': false,
  'referenced_schema': 'public',
  'referenced_relation': 'users',
  'referenced_columns': ['id'],
};

const postsToUsersView = <String, dynamic>{
  'foreign_key_name': 'posts_author_id_fkey',
  'schema': 'public',
  'relation': 'posts',
  'columns': ['author_id'],
  'is_one_to_one': false,
  'referenced_schema': 'public',
  'referenced_relation': 'users_view',
  'referenced_columns': ['id'],
};

const postsViewToUsersView = <String, dynamic>{
  'foreign_key_name': 'posts_author_id_fkey',
  'schema': 'public',
  'relation': 'posts_view',
  'columns': ['author_id'],
  'is_one_to_one': false,
  'referenced_schema': 'public',
  'referenced_relation': 'users_view',
  'referenced_columns': ['id'],
};

void main() {
  group('expandViewRelationships', () {
    test('expands a view to table dependency', () {
      expect(expandViewRelationships([postsAuthorFk], [viewToTableDep]), [
        postsViewToUsers,
      ]);
    });

    test('expands a table to view dependency', () {
      expect(expandViewRelationships([postsAuthorFk], [tableToViewDep]), [
        postsToUsersView,
      ]);
    });

    test('combines both dependency kinds into a view to view relationship', () {
      expect(
        expandViewRelationships(
          [postsAuthorFk],
          [viewToTableDep, tableToViewDep],
        ),
        [postsViewToUsers, postsToUsersView, postsViewToUsersView],
      );
    });

    test('takes the cartesian product over view columns of composite keys', () {
      const compositeFk = <String, dynamic>{
        'foreign_key_name': 'memberships_org_fkey',
        'schema': 'public',
        'relation': 'memberships',
        'columns': ['org_id', 'user_id'],
        'is_one_to_one': true,
        'referenced_schema': 'public',
        'referenced_relation': 'orgs',
        'referenced_columns': ['org_id', 'owner_id'],
      };
      const compositeDep = <String, dynamic>{
        'table_schema': 'public',
        'table_name': 'memberships',
        'view_schema': 'public',
        'view_name': 'memberships_view',
        'constraint_name': 'memberships_org_fkey',
        'constraint_type': 'f',
        'column_dependencies': [
          {
            'table_column': 'org_id',
            'view_columns': ['org_id', 'organization_id'],
          },
          {
            'table_column': 'user_id',
            'view_columns': ['user_id', 'member_id'],
          },
        ],
      };

      final result = expandViewRelationships([compositeFk], [compositeDep]);

      expect(result.map((relationship) => relationship['columns']), [
        ['org_id', 'user_id'],
        ['org_id', 'member_id'],
        ['organization_id', 'user_id'],
        ['organization_id', 'member_id'],
      ]);
      expect(
        result.every(
          (relationship) =>
              relationship['relation'] == 'memberships_view' &&
              relationship['is_one_to_one'] == true,
        ),
        isTrue,
      );
    });

    test('returns nothing when no view depends on the relationship', () {
      expect(expandViewRelationships([postsAuthorFk], []), isEmpty);
    });
  });
}
