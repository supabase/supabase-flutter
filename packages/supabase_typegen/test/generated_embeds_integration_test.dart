// The typed table access API under test is annotated @experimental.
// ignore_for_file: experimental_member_use

import 'package:postgrest/postgrest.dart';
import 'package:supabase_common/testing.dart';
import 'package:test/test.dart';

import 'goldens/hostile_schema.dart';

/// Embeds the relations generated in the hostile golden against the tables
/// of the same shape the local stack defines in
/// `supabase/migrations/20240101000005_embed_disambiguation.sql`.
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

    expect([for (final badge in badges) badge.read(Badge.profile)], [1, 1]);
    expect(
      [
        for (final badge in badges)
          badge.read(Badge.profileByProfile)?.read(Profile.name),
      ],
      ['Ada', 'Ada'],
    );
  });
}
