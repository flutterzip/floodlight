import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fixture.dart';
import '../models/league.dart';
import '../models/match.dart';
import '../models/standing.dart';
import '../services/store.dart';
import 'core_providers.dart';

/// The fixtures around now, sorted into what is on, what is next and what
/// is over. Two boards with the same matches in the same places are equal,
/// so a list only rebuilds when a match starts or ends, not every second.
@immutable
class Board {
  Board({required this.live, required this.upcoming, required this.finished})
    : _key = [
        live,
        upcoming,
        finished,
      ].map((l) => l.map((f) => f.id).join(',')).join('|');

  static final empty = Board(
    live: const [],
    upcoming: const [],
    finished: const [],
  );

  /// Earliest start first.
  final List<Fixture> live;
  final List<Fixture> upcoming;

  /// Most recently finished first.
  final List<Fixture> finished;
  final String _key;

  Iterable<Fixture> get all => [...live, ...upcoming, ...finished];

  Board only(Sport? sport) => sport == null
      ? this
      : Board(
          live: [
            for (final f in live)
              if (f.sport == sport) f,
          ],
          upcoming: [
            for (final f in upcoming)
              if (f.sport == sport) f,
          ],
          finished: [
            for (final f in finished)
              if (f.sport == sport) f,
          ],
        );

  @override
  bool operator ==(Object other) => other is Board && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

final boardProvider = Provider<Board>((ref) {
  final scores = ref.watch(scoresProvider);
  if (scores == null) return Board.empty;
  final now = ref.watch(nowProvider);
  final live = <Fixture>[], upcoming = <Fixture>[];
  final finished = <(DateTime, Fixture)>[];
  for (final f in scores.fixtures(now)) {
    if (now.isBefore(f.kickoff)) {
      upcoming.add(f);
    } else {
      final end = scores.endOf(f.id)!;
      if (now.isBefore(end)) {
        live.add(f);
      } else {
        finished.add((end, f));
      }
    }
  }
  int byStart(Fixture a, Fixture b) => a.kickoff.compareTo(b.kickoff);
  return Board(
    live: live..sort(byStart),
    upcoming: upcoming..sort(byStart),
    finished: [
      for (final e in finished..sort((a, b) => b.$1.compareTo(a.$1))) e.$2,
    ],
  );
});

/// The sport the scores are narrowed to, or null for all of them.
class SportFilterNotifier extends Notifier<Sport?> {
  @override
  Sport? build() =>
      Sport.values.asNameMap()[ref.watch(storeProvider).string(Store.sport)];

  Future<void> set(Sport? sport) async {
    state = sport;
    await ref.read(storeProvider).setString(Store.sport, sport?.name);
  }
}

final sportFilterProvider = NotifierProvider<SportFilterNotifier, Sport?>(
  SportFilterNotifier.new,
);

final filteredBoardProvider = Provider<Board>(
  (ref) => ref.watch(boardProvider).only(ref.watch(sportFilterProvider)),
);

/// A match right now. The engine hands back the identical snapshot until
/// something happens in the match, so watching this costs nothing between
/// events.
final matchProvider = Provider.family<MatchSnapshot?, String>(
  (ref, id) => ref.watch(scoresProvider)?.match(id, ref.watch(nowProvider)),
);

/// A match's running clock: "67'", "Q3 4:12", "14.3 ov".
final matchClockProvider = Provider.family<String, String>(
  (ref, id) =>
      ref.watch(scoresProvider)?.clock(id, ref.watch(nowProvider)) ?? '',
);

/// Whole seconds until [id] starts, or zero once it has.
final startsInProvider = Provider.family<int, String>((ref, id) {
  final f = ref.watch(scoresProvider)?.fixture(id);
  if (f == null) return 0;
  final left = f.kickoff.difference(ref.watch(nowProvider));
  return left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
});

final competitionsProvider = Provider<List<Competition>>(
  (ref) => ref.watch(scoresProvider)?.competitions ?? const [],
);

final competitionProvider = Provider.family<Competition?, String>((ref, id) {
  for (final c in ref.watch(competitionsProvider)) {
    if (c.id == id) return c;
  }
  return null;
});

final teamProvider = Provider.family<Team?, String>(
  (ref, id) => ref.watch(scoresProvider)?.teams[id],
);

/// A competition's table. Added up from results, and the same list object
/// until a match starts or ends.
final tableProvider = Provider.family<List<StandingRow>, String>(
  (ref, id) =>
      ref.watch(scoresProvider)?.table(id, ref.watch(nowProvider)) ?? const [],
);

/// A team's row in its table.
final standingProvider = Provider.family<StandingRow?, String>((ref, teamId) {
  final scores = ref.watch(scoresProvider);
  if (scores == null || !scores.teams.containsKey(teamId)) return null;
  for (final r in ref.watch(tableProvider(scores.competitionOf(teamId).id))) {
    if (r.team.id == teamId) return r;
  }
  return null;
});

/// Every match a team has this season, in order.
final teamSeasonProvider = Provider.family<List<Fixture>, String>(
  (ref, teamId) =>
      ref.watch(scoresProvider)?.seasonOf(teamId, ref.watch(minuteProvider)) ??
      const [],
);

/// The match a team is playing now, or failing that its next one, or
/// failing that its last.
final teamFocusProvider = Provider.family<Fixture?, String>((ref, teamId) {
  final board = ref.watch(boardProvider);
  for (final list in [board.live, board.upcoming, board.finished]) {
    for (final f in list) {
      if (f.involves(teamId)) return f;
    }
  }
  return null;
});
