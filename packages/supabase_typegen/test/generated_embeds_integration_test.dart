// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

@Tags(['integration'])
library;

import 'package:postgrest/postgrest.dart';
import 'package:supabase_common/testing.dart';
import 'package:test/test.dart';

import 'goldens/hostile_schema.dart';

/// Embeds the relations generated in the hostile golden against the tables
/// of the same shape the local stack defines in
/// `supabase/migrations/20240101000005_embed_disambiguation.sql` and
/// `supabase/migrations/20240101000006_hidden_schema_views.sql`.
void main() {
  late PostgrestClient client;

  setUp(() {
    client = PostgrestClient(
      localStackRestUrl,
      headers: {
        'apikey': localStackServiceRoleKey,
        'Authorization': 'Bearer $localStackServiceRoleKey',
      },
    );
  });

  tearDown(() async {
    await client.dispose();
  });

  test('embeds of keys in opposite directions resolve separately', () async {
    final profiles = await client
        .table(Profile.table)
        .selectOnly([
          Profile.id,
          Profile.team,
          Profile.teamByTeam.select([Team.name]),
          Profile.teamViaOwnerId.select([Team.name]),
        ])
        .order(Profile.id);

    expect(
      [for (final profile in profiles) profile.read(Profile.team)],
      [
        1,
        1,
        null,
      ],
    );
    expect(
      [
        for (final profile in profiles)
          profile.read(Profile.teamByTeam)?.read(Team.name),
      ],
      ['Rockets', 'Rockets', null],
    );
    expect(
      [
        for (final profile in profiles)
          [
            for (final team in profile.read(Profile.teamViaOwnerId))
              team.read(Team.name),
          ],
      ],
      [
        ['Comets'],
        ['Rockets'],
        <String>[],
      ],
    );
  });

  test('the other side of opposite keys resolves separately', () async {
    final teams = await client
        .table(Team.table)
        .selectOnly([
          Team.profileViaTeam.select([Profile.name]),
          Team.profileByOwnerId.select([Profile.name]),
        ])
        .order(Team.id);

    expect(
      [
        for (final team in teams)
          [
            for (final profile in team.read(Team.profileViaTeam))
              profile.read(Profile.name),
          ]..sort(),
      ],
      [
        ['Ada', 'Grace'],
        <String>[],
      ],
    );
    expect(
      [
        for (final team in teams)
          team.read(Team.profileByOwnerId)?.read(Profile.name),
      ],
      ['Grace', 'Ada'],
    );
  });

  test('an embed named like a column keeps the column readable', () async {
    final badges = await client
        .table(Badge.table)
        .selectOnly([
          Badge.profile,
          Badge.profileByProfile.select([Profile.name]),
        ])
        .order(Badge.id);

    expect(
      [for (final badge in badges) badge.read(Badge.profile)],
      [1, 1],
    );
    expect(
      [
        for (final badge in badges)
          badge.read(Badge.profileByProfile)?.read(Profile.name),
      ],
      ['Ada', 'Ada'],
    );
  });

  test('a key next to a junction table resolves', () async {
    final badges = await client
        .table(Badge.table)
        .selectOnly([
          Badge.team,
          Badge.teamByTeam.select([Team.name]),
        ])
        .order(Badge.id);

    expect(
      [for (final badge in badges) badge.read(Badge.team)],
      [1, null],
    );
    expect(
      [
        for (final badge in badges)
          badge.read(Badge.teamByTeam)?.read(Team.name),
      ],
      ['Rockets', null],
    );

    final teams = await client
        .table(Team.table)
        .selectOnly([
          Team.badgeViaTeam.select([Badge.name]),
        ])
        .order(Team.id);

    expect(
      [
        for (final team in teams)
          [
            for (final badge in team.read(Team.badgeViaTeam))
              badge.read(Badge.name),
          ],
      ],
      [
        ['Founder'],
        <String>[],
      ],
    );
  });

  test('views over tables of a schema that is not exposed embed each other '
      'and the tables their keys reference', () async {
    final replies = await client.table(NoteReply.table).selectOnly([
      NoteReply.body,
      NoteReply.note.select([
        Note.body,
        Note.team.select([Team.name]),
      ]),
    ]);

    expect(
      [
        for (final reply in replies)
          (
            reply.read(NoteReply.body),
            reply.read(NoteReply.note)?.read(Note.body),
            reply.read(NoteReply.note)?.read(Note.team)?.read(Team.name),
          ),
      ],
      [('Go', 'Launch', 'Rockets')],
    );

    final teams = await client
        .table(Team.table)
        .selectOnly([
          Team.note.select([
            Note.body,
            Note.noteReply.select([NoteReply.body]),
          ]),
        ])
        .order(Team.id);

    expect(
      [
        for (final team in teams)
          [
            for (final note in team.read(Team.note)) ...[
              note.read(Note.body),
              for (final reply in note.read(Note.noteReply))
                reply.read(NoteReply.body),
            ],
          ],
      ],
      [
        ['Launch', 'Go'],
        ['Orbit'],
      ],
    );
  });
}
