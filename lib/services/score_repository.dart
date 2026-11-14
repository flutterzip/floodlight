import '../engine/basketball.dart';
import '../engine/cricket.dart';
import '../engine/football.dart';
import '../engine/match_script.dart';
import '../engine/schedule.dart';
import '../engine/standings.dart';
import '../models/fixture.dart';
import '../models/league.dart';
import '../models/match.dart';
import '../models/standing.dart';
import 'seed.dart';

/// Competitions, fixtures, live matches and tables.
///
/// Reads are synchronous on purpose. A live screen asks for the latest
/// state several times a second, so the repository answers from memory and
/// keeps that memory fresh on its own. Here the "memory" is the match
/// engine; a network implementation fills the same shapes from its feed
/// (see the sketch at the bottom of this file). Everything takes the time
/// as an argument, so a test can stand at any second of any match.
abstract interface class ScoreRepository {
  List<Competition> get competitions;
  Map<String, Team> get teams;

  Competition competitionOf(String teamId);

  /// The rounds just gone, under way and next up, for every competition.
  List<Fixture> fixtures(DateTime now);

  Fixture? fixture(String id);

  /// A fixture placed relative to the round under way at [at]: -1 is the
  /// round before it, 1 the round after.
  Fixture? fixtureNear(
    String competitionId,
    DateTime at, {
    required int round,
    required int index,
  });

  MatchSnapshot? match(String id, DateTime now);

  /// The running clock: "67'", "Q3 4:12", "14.3 ov". Empty before the start.
  String clock(String id, DateTime now);

  /// When the match will be, or was, over.
  DateTime? endOf(String id);

  List<StandingRow> table(String competitionId, DateTime now);

  /// Every match a team has this season, played and to come.
  List<Fixture> seasonOf(String teamId, DateTime now);

  /// Asks for the latest. The engine has nothing to fetch.
  Future<void> refresh();
}

/// The demo league: every match is worked out from the clock by the engines
/// in `lib/engine/`, so there is always something live.
class SimulatedScoreRepository implements ScoreRepository {
  SimulatedScoreRepository(Seed seed)
    : teams = {
        for (final j in seed.rows('teams')) j['id'] as String: Team.fromJson(j),
      },
      competitions = [
        for (final j in seed.rows('competitions')) Competition.fromJson(j),
      ] {
    for (var i = 0; i < competitions.length; i++) {
      final c = competitions[i];
      _schedules[c.id] = LeagueSchedule(c, phase: Pace.phase * i);
      for (final t in c.teamIds) {
        _home[t] = c;
      }
    }
  }

  @override
  final Map<String, Team> teams;

  @override
  final List<Competition> competitions;

  final _schedules = <String, LeagueSchedule>{};
  final _home = <String, Competition>{};
  final _scripts = <String, MatchScript>{};
  final _tables = <String, (String, List<StandingRow>)>{};

  /// Matches kept in memory. A season's worth for every competition fits.
  static const _keep = 480;

  @override
  Competition competitionOf(String teamId) => _home[teamId]!;

  MatchScript? _script(String id) {
    final cached = _scripts.remove(id);
    if (cached != null) return _scripts[id] = cached;
    final f = fixture(id);
    if (f == null) return null;
    final home = teams[f.homeId], away = teams[f.awayId];
    if (home == null || away == null) return null;
    final MatchScript script = switch (f.sport) {
      Sport.football => FootballScript(f, home, away),
      Sport.basketball => BasketballScript(f, home, away),
      Sport.cricket => CricketScript(f, home, away),
    };
    if (_scripts.length >= _keep) _scripts.remove(_scripts.keys.first);
    return _scripts[id] = script;
  }

  @override
  Fixture? fixture(String id) {
    final ref = parseFixtureId(id);
    return ref == null ? null : _schedules[ref.competitionId]?.byId(id);
  }

  @override
  Fixture? fixtureNear(
    String competitionId,
    DateTime at, {
    required int round,
    required int index,
  }) {
    final s = _schedules[competitionId];
    if (s == null) return null;
    final r = s.absoluteRoundAt(at) + round;
    if (r < 0 || index < 0 || index >= s.fixturesPerRound) return null;
    return s.round(r)[index];
  }

  @override
  List<Fixture> fixtures(DateTime now) => [
    for (final s in _schedules.values)
      for (
        var r = s.absoluteRoundAt(now) - 1;
        r <= s.absoluteRoundAt(now) + 1;
        r++
      )
        if (r >= 0) ...s.round(r),
  ];

  @override
  MatchSnapshot? match(String id, DateTime now) {
    final s = _script(id);
    return s?.at(now.difference(s.fixture.kickoff));
  }

  @override
  String clock(String id, DateTime now) {
    final s = _script(id);
    return s == null ? '' : s.clockAt(now.difference(s.fixture.kickoff));
  }

  @override
  DateTime? endOf(String id) {
    final s = _script(id);
    return s?.fixture.kickoff.add(s.length);
  }

  bool _over(Fixture f, DateTime now) {
    final end = endOf(f.id);
    return end != null && !now.isBefore(end);
  }

  @override
  List<StandingRow> table(String competitionId, DateTime now) {
    final s = _schedules[competitionId];
    if (s == null) return const [];
    final current = s.absoluteRoundAt(now);
    final done = <Fixture>[];
    final playing = <String>{};
    for (final r in s.seasonSoFar(current)) {
      if (r < 0) continue;
      for (final f in s.round(r)) {
        // Anything two rounds back finished long ago: no need to ask.
        if (r < current - 1 || _over(f, now)) {
          done.add(f);
        } else if (!now.isBefore(f.kickoff)) {
          playing
            ..add(f.homeId)
            ..add(f.awayId);
        }
      }
    }
    // The table only changes when a match ends or starts.
    final key =
        '${done.length}:${done.isEmpty ? '' : done.last.id}:'
        '${playing.length}';
    final cached = _tables[competitionId];
    if (cached != null && cached.$1 == key) return cached.$2;
    final rows = buildTable(
      competition: s.competition,
      teams: teams,
      finished: [
        for (final f in done)
          if (_script(f.id) case final script?) script.finalState,
      ],
      playing: playing,
    );
    _tables[competitionId] = (key, rows);
    return rows;
  }

  @override
  List<Fixture> seasonOf(String teamId, DateTime now) {
    final s = _schedules[_home[teamId]?.id];
    if (s == null) return const [];
    final current = s.absoluteRoundAt(now);
    final first = s.seasonOf(current < 0 ? 0 : current) * s.roundsPerSeason;
    return [
      for (var r = first; r < first + s.roundsPerSeason; r++)
        for (final f in s.round(r))
          if (f.involves(teamId)) f,
    ];
  }

  @override
  Future<void> refresh() async {}
}

// A network implementation keeps the latest known state in memory and
// serves the same synchronous reads from it. The models already use the
// shapes an API would send, so only the transport is new:
//
// class RemoteScoreRepository implements ScoreRepository {
//   RemoteScoreRepository(this._dio, this._socket) {
//     _socket.stream.listen((frame) {
//       final snapshot = snapshotFromJson(frame);   // one per sport
//       _latest[snapshot.id] = snapshot;
//     });
//   }
//   final _latest = <String, MatchSnapshot>{};
//
//   @override
//   MatchSnapshot? match(String id, DateTime now) => _latest[id];
//
//   @override
//   Future<void> refresh() async {
//     final r = await _dio.get('/fixtures', queryParameters: {'around': 'now'});
//     ...
//   }
// }
