import 'dart:io';

import 'package:floodlight/models/league.dart';
import 'package:floodlight/models/match.dart';
import 'package:floodlight/models/pick.dart';
import 'package:floodlight/models/format.dart';
import 'package:floodlight/services/account_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  final scores = league(seed);

  test('every sport has a competition, and every team exactly one', () {
    expect({
      for (final c in scores.competitions) c.sport,
    }, Sport.values.toSet());
    final seen = <String>{};
    for (final c in scores.competitions) {
      expect(c.teamIds.length.isEven, isTrue, reason: c.id);
      for (final id in c.teamIds) {
        expect(seen.add(id), isTrue, reason: '$id is in two competitions');
        expect(scores.teams[id]!.sport, c.sport);
        expect(scores.competitionOf(id).id, c.id);
      }
    }
    expect(seen, scores.teams.keys.toSet());
  });

  test('squads are the size and shape their sport needs', () {
    for (final t in scores.teams.values) {
      final roles = [for (final p in t.squad) p.role];
      expect(t.short.length, 3, reason: t.id);
      expect({for (final p in t.squad) p.id}.length, t.squad.length);
      switch (t.sport) {
        case Sport.football:
          expect(t.squad.length, 18);
          expect(roles.first, 'GK');
          // The eleven are in the order of the formation.
          final rows = t.formation.split('-').map(int.parse).toList();
          expect(rows.fold(0, (a, b) => a + b), 10, reason: t.formation);
          expect(roles.skip(1).take(rows.first).toSet(), {'DF'});
          expect(roles.skip(11 - rows.last).take(rows.last).toSet(), {'FW'});
        case Sport.basketball:
          expect(t.squad.length, 9);
          expect(roles.take(5), ['G', 'G', 'F', 'F', 'C']);
        case Sport.cricket:
          expect(t.squad.length, 11);
          expect(roles.where((r) => r == 'WK').length, 1);
          // Five bowlers at four overs each is the least that can bowl twenty.
          expect(
            roles.where((r) => r == 'BWL' || r == 'AR').length,
            greaterThanOrEqualTo(5),
          );
      }
    }
  });

  test('no two teams in a competition share a crest colour', () {
    for (final c in scores.competitions) {
      final tints = [for (final id in c.teamIds) scores.teams[id]!.crest.tint];
      expect(tints.toSet().length, tints.length, reason: c.id);
    }
  });

  test('colour is never in the seed: only an index into the palette', () {
    for (final f in Directory('assets/data').listSync().whereType<File>()) {
      final text = f.readAsStringSync();
      expect(
        RegExp(r'#[0-9A-Fa-f]{6}\b').hasMatch(text),
        isFalse,
        reason: f.path,
      );
      expect(text.contains('0xFF'), isFalse, reason: f.path);
    }
  });

  test('the demo person and the teams they follow are real', () {
    expect(seed.profile.name, 'Olympicson');
    expect(seed.profile.email, 'hello@flutterzip.com');
    expect(seed.demoEmail, seed.profile.email);
    expect(seed.wrongPassword, 'wrongpass');
    expect(seed.following, isNotEmpty);
    for (final id in seed.following) {
      expect(scores.teams.containsKey(id), isTrue, reason: id);
    }
    // One from each sport, so every kind of match reaches the live pill.
    expect({
      for (final id in seed.following) scores.teams[id]!.sport,
    }, Sport.values.toSet());
  });

  test('seeded picks land on real matches, with one of each outcome', () {
    for (final minutes in [0, 7, 31, 96]) {
      final first = testNow.add(Duration(minutes: minutes));
      final picks = LocalAccountRepository.seedPicks(seed, scores, first);
      expect(picks.length, seed.picks.length);
      expect({for (final p in picks) p.fixtureId}.length, picks.length);
      final results = [
        for (final p in picks) p.resultFor(scores.match(p.fixtureId, first)!),
      ];
      expect(results.where((r) => r == PickResult.open).length, 2);
      expect(results.where((r) => r == PickResult.won).length, 3);
      expect(results.where((r) => r == PickResult.lost).length, 1);
      // An open pick was made before its match started.
      for (final p in picks) {
        final m = scores.match(p.fixtureId, first)!;
        expect(p.madeAt.isBefore(m.fixture.kickoff), isTrue);
        if (p.resultFor(m) == PickResult.open) {
          expect(m.stage, MatchStage.upcoming);
        }
      }
    }
  });

  test('a pick round trips through storage', () {
    final p = LocalAccountRepository.seedPicks(seed, scores, testNow).first;
    final again = Pick.fromJson(p.toJson());
    expect(again.id, p.id);
    expect(again.fixtureId, p.fixtureId);
    expect(again.choice, p.choice);
    expect(again.madeAt, p.madeAt);
    expect(
      const AlertPrefs().copyWith(scores: false).toJson()['scores'],
      false,
    );
    expect(AlertPrefs.fromJson(const {}).results, isTrue);
  });

  test('times and waits read the way a person says them', () {
    expect(countdown(134), '2:14');
    expect(countdown(5), '0:05');
    expect(countdown(3734), '1:02:14');
    expect(countdown(-3), '0:00');
    final now = DateTime(2026, 11, 14, 12);
    expect(
      agoLabel(now.subtract(const Duration(seconds: 10)), now),
      'Just now',
    );
    expect(
      agoLabel(now.subtract(const Duration(minutes: 4)), now),
      '4 min ago',
    );
    expect(agoLabel(now.subtract(const Duration(hours: 2)), now), '2 h ago');
    expect(percent(.634), '63%');
  });
}
