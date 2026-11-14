import '../models/fixture.dart';
import '../models/league.dart';

/// How fast the demo league plays. A match takes about nine minutes of real
/// time, a round sixteen, and the season never stops, so there is always
/// something live whenever the app is opened. Nothing here is stored: the
/// whole calendar is worked out from the time.
abstract final class Pace {
  /// The first round of the first season starts here.
  static final epoch = DateTime.utc(2026, 1, 1);

  static const round = Duration(minutes: 16);

  /// The gap between one kick-off and the next within a round.
  static const stagger = Duration(seconds: 90);

  /// Each competition starts its rounds this much after the one before it,
  /// so their quiet spells do not line up.
  static const phase = Duration(seconds: 250);
}

/// A double round robin that repeats for ever.
class LeagueSchedule {
  LeagueSchedule(this.competition, {required this.phase})
    : assert(competition.teamIds.length.isEven);

  final Competition competition;

  /// This competition's offset from [Pace.epoch].
  final Duration phase;

  int get _teams => competition.teamIds.length;
  int get roundsPerSeason => 2 * (_teams - 1);
  int get fixturesPerRound => _teams ~/ 2;

  DateTime get _start => Pace.epoch.add(phase);

  /// The round under way at [now] (or the last to have started), counted
  /// from the epoch.
  int absoluteRoundAt(DateTime now) =>
      (now.difference(_start).inMicroseconds / Pace.round.inMicroseconds)
          .floor();

  int seasonOf(int absoluteRound) => absoluteRound ~/ roundsPerSeason;
  int roundOf(int absoluteRound) => absoluteRound % roundsPerSeason;

  DateTime roundStart(int absoluteRound) =>
      _start.add(Pace.round * absoluteRound);

  /// The fixtures of one round, by the circle method: one team stays put,
  /// the rest rotate round it. The second half of the season mirrors the
  /// first with home and away swapped.
  List<Fixture> round(int absoluteRound) {
    final n = _teams;
    final r = roundOf(absoluteRound);
    final leg = r ~/ (n - 1);
    final turn = r % (n - 1);
    final ids = competition.teamIds;
    final ring = [
      ids.first,
      for (var i = 0; i < n - 1; i++) ids[1 + (i + turn) % (n - 1)],
    ];
    final start = roundStart(absoluteRound);
    return [
      for (var i = 0; i < n ~/ 2; i++)
        () {
          var a = ring[i], b = ring[n - 1 - i];
          // Alternate who hosts so nobody is at home all season.
          if ((turn + i).isOdd) (a, b) = (b, a);
          if (leg == 1) (a, b) = (b, a);
          return Fixture(
            id: '${competition.id}:$absoluteRound:$i',
            competitionId: competition.id,
            sport: competition.sport,
            season: seasonOf(absoluteRound) + 1,
            round: r + 1,
            index: i,
            homeId: a,
            awayId: b,
            kickoff: start.add(Pace.stagger * i),
          );
        }(),
    ];
  }

  Fixture? byId(String id) {
    final ref = parseFixtureId(id);
    if (ref == null || ref.competitionId != competition.id) return null;
    if (ref.absoluteRound < 0) return null;
    if (ref.index < 0 || ref.index >= fixturesPerRound) return null;
    return round(ref.absoluteRound)[ref.index];
  }

  /// Every round of the season [absoluteRound] belongs to, up to and
  /// including it.
  Iterable<int> seasonSoFar(int absoluteRound) sync* {
    final first = seasonOf(absoluteRound) * roundsPerSeason;
    for (var r = first; r <= absoluteRound; r++) {
      yield r;
    }
  }
}
