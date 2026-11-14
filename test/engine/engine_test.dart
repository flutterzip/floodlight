import 'package:floodlight/engine/rng.dart';
import 'package:floodlight/engine/schedule.dart';
import 'package:floodlight/models/basketball.dart';
import 'package:floodlight/models/cricket.dart';
import 'package:floodlight/models/fixture.dart';
import 'package:floodlight/models/football.dart';
import 'package:floodlight/models/league.dart';
import 'package:floodlight/models/match.dart';
import 'package:floodlight/models/standing.dart';
import 'package:floodlight/services/score_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final seed = readSeed();
  late ScoreRepository scores;
  setUp(() => scores = league(seed));

  /// Every fixture of the three rounds around [testNow], finished.
  List<T> finals<T extends MatchSnapshot>() => [
    for (final f in scores.fixtures(testNow))
      if (scores.match(f.id, scores.endOf(f.id)!) case final T m) m,
  ];

  group('the generator', () {
    test('the same key always gives the same run', () {
      final a = Rng.of('cpl:10:2'), b = Rng.of('cpl:10:2');
      expect(
        [for (var i = 0; i < 50; i++) a.d()],
        [for (var i = 0; i < 50; i++) b.d()],
      );
      expect(Rng.of('cpl:10:3').d(), isNot(Rng.of('cpl:10:2').d()));
    });

    test('stays between 0 and 1 and spreads evenly', () {
      final r = Rng(7);
      var sum = 0.0;
      for (var i = 0; i < 20000; i++) {
        final v = r.d();
        expect(v, inInclusiveRange(0, 1));
        sum += v;
      }
      expect(sum / 20000, closeTo(.5, .02));
    });
  });

  group('the calendar', () {
    test('every team plays exactly once in a round', () {
      for (final c in scores.competitions) {
        final s = LeagueSchedule(c, phase: Duration.zero);
        for (var r = 0; r < s.roundsPerSeason * 2; r++) {
          final teams = [
            for (final f in s.round(r)) ...[f.homeId, f.awayId],
          ];
          expect(teams.toSet(), c.teamIds.toSet(), reason: '${c.id} round $r');
          expect(teams.length, c.teamIds.length);
        }
      }
    });

    test('a season is every pair, home and away, once each', () {
      final c = scores.competitions.first;
      final s = LeagueSchedule(c, phase: Duration.zero);
      final pairs = <String>{};
      for (var r = 0; r < s.roundsPerSeason; r++) {
        for (final f in s.round(r)) {
          expect(pairs.add('${f.homeId}>${f.awayId}'), isTrue);
        }
      }
      final n = c.teamIds.length;
      expect(pairs.length, n * (n - 1));
    });

    test('a fixture can be rebuilt from its id alone', () {
      for (final f in scores.fixtures(testNow)) {
        final again = scores.fixture(f.id)!;
        expect(again.homeId, f.homeId);
        expect(again.awayId, f.awayId);
        expect(again.kickoff, f.kickoff);
        expect(parseFixtureId(f.id)!.index, f.index);
      }
      expect(scores.fixture('nonsense'), isNull);
      expect(scores.fixture('cpl:-4:0'), isNull);
      expect(scores.fixture('cpl:3:99'), isNull);
    });

    test('there is always something live, about to start and just over', () {
      for (var minutes = 0; minutes < 180; minutes += 7) {
        final at = testNow.add(Duration(minutes: minutes));
        final all = scores.fixtures(at);
        bool live(Fixture f) =>
            !at.isBefore(f.kickoff) && at.isBefore(scores.endOf(f.id)!);
        expect(all.where(live), isNotEmpty, reason: '+$minutes min');
        expect(all.where((f) => at.isBefore(f.kickoff)), isNotEmpty);
        expect(all.where((f) => !at.isBefore(scores.endOf(f.id)!)), isNotEmpty);
      }
    });

    test('a team is never in two matches at once', () {
      final all = scores.fixtures(testNow);
      for (final f in all) {
        final round = parseFixtureId(f.id)!.absoluteRound;
        final end = scores.endOf(f.id)!;
        for (final next in all) {
          if (next.competitionId != f.competitionId) continue;
          if (parseFixtureId(next.id)!.absoluteRound != round + 1) continue;
          if (next.involves(f.homeId) || next.involves(f.awayId)) {
            expect(end.isBefore(next.kickoff), isTrue, reason: f.id);
          }
        }
      }
    });
  });

  group('a match, whatever the sport', () {
    test('is the same match every time it is asked for', () {
      final f = fixtureIn(scores, Sport.football, Phase.finished);
      final end = scores.endOf(f.id)!;
      final a = league(seed).match(f.id, end)!;
      final b = league(seed).match(f.id, end)!;
      expect(a.score(Side.home).main, b.score(Side.home).main);
      expect(a.feed.length, b.feed.length);
      expect(a.headline, b.headline);
    });

    test('hands back the identical snapshot until something happens', () {
      final f = fixtureIn(scores, Sport.football, Phase.live);
      final a = scores.match(f.id, testNow)!;
      final b = scores.match(
        f.id,
        testNow.add(const Duration(milliseconds: 40)),
      )!;
      expect(identical(a, b), isTrue);
      final later = scores.match(
        f.id,
        testNow.add(const Duration(seconds: 30)),
      )!;
      expect(later.revision, greaterThan(a.revision));
    });

    test('goes from upcoming through live to finished', () {
      for (final sport in Sport.values) {
        final f = fixtureIn(scores, sport, Phase.upcoming);
        final end = scores.endOf(f.id)!;
        final before = scores.match(
          f.id,
          f.kickoff.subtract(const Duration(seconds: 5)),
        )!;
        expect(before.stage, MatchStage.upcoming);
        expect(before.score(Side.home).main, isEmpty);
        expect(
          scores.clock(
            f.id,
            before.fixture.kickoff.subtract(const Duration(seconds: 5)),
          ),
          isEmpty,
        );
        final during = scores.match(
          f.id,
          f.kickoff.add(const Duration(seconds: 60)),
        )!;
        expect(during.stage, MatchStage.live);
        expect(
          scores.clock(f.id, f.kickoff.add(const Duration(seconds: 60))),
          isNotEmpty,
        );
        final after = scores.match(f.id, end)!;
        expect(after.stage, MatchStage.finished);
        expect(
          after.chance.home + after.chance.draw + after.chance.away,
          closeTo(1, 1e-9),
        );
      }
    });

    test('never goes backwards, and the chances always add up to one', () {
      for (final sport in Sport.values) {
        final f = fixtureIn(scores, sport, Phase.upcoming);
        final end = scores.endOf(f.id)!;
        var revision = -1, moments = -1;
        for (
          var at = f.kickoff;
          !at.isAfter(end);
          at = at.add(const Duration(seconds: 3))
        ) {
          final m = scores.match(f.id, at)!;
          expect(m.revision, greaterThanOrEqualTo(revision));
          expect(m.scoringMoments, greaterThanOrEqualTo(moments));
          revision = m.revision;
          moments = m.scoringMoments;
          final c = m.chance;
          expect(c.home + c.draw + c.away, closeTo(1, 1e-6));
          expect(c.home, inInclusiveRange(0, 1));
        }
      }
    });

    test('feed lines are in order and each has an id of its own', () {
      for (final m in finals<MatchSnapshot>()) {
        final ids = m.feed.map((f) => f.id).toSet();
        expect(ids.length, m.feed.length, reason: m.id);
        for (var i = 1; i < m.feed.length; i++) {
          expect(m.feed[i].at >= m.feed[i - 1].at, isTrue, reason: m.id);
        }
        expect(m.feed.last.major, isTrue);
      }
    });
  });

  group('football', () {
    test('the score is the goals in the events', () {
      for (final m in finals<FootballSnapshot>()) {
        for (final s in Side.values) {
          expect(
            m.goalEvents.where((e) => e.side == s).length,
            m.goals(s),
            reason: m.id,
          );
        }
        expect(m.minute, m.totalMinutes);
        expect(m.momentum.length, m.totalMinutes);
        expect(m.period, FootballPeriod.fullTime);
      }
    });

    test('the statistics hang together', () {
      for (final m in finals<FootballSnapshot>()) {
        final by = {for (final s in m.stats) s.label: s};
        expect(
          by['Possession']!.home + by['Possession']!.away,
          closeTo(100, .01),
        );
        expect(by['Shots']!.home, greaterThanOrEqualTo(by['On target']!.home));
        expect(by['On target']!.home, greaterThanOrEqualTo(m.homeGoals));
        expect(by['On target']!.away, greaterThanOrEqualTo(m.awayGoals));
        expect(by['Pass accuracy']!.home, inInclusiveRange(0, 100));
      }
    });

    test('eleven line up, in the shape the team plays', () {
      for (final m in finals<FootballSnapshot>()) {
        expect(m.homeLineup.length, 11);
        expect(m.awayLineup.length, 11);
        for (final s in [...m.homeLineup, ...m.awayLineup]) {
          expect(s.x, inExclusiveRange(0, 1));
          expect(s.y, inInclusiveRange(0, 1));
        }
        final scorers = {
          for (final s in [...m.homeLineup, ...m.awayLineup])
            if (s.goals > 0) s.player.id,
        };
        // A scorer who started is marked; one who came on is not on the
        // pitch drawing at all.
        for (final g in m.goalEvents) {
          final starter = m
              .team(g.side)
              .squad
              .take(11)
              .any((p) => p.id == g.playerId);
          expect(scorers.contains(g.playerId), starter, reason: m.id);
        }
      }
    });

    test('the clock reads like a football clock', () {
      final f = fixtureIn(scores, Sport.football, Phase.upcoming);
      String at(double seconds) => scores.clock(
        f.id,
        f.kickoff.add(Duration(milliseconds: (seconds * 1000).round())),
      );
      expect(at(.1), "1'");
      expect(at(5 * 44 + 1), "45'");
      expect(at(5 * 45 + 1), "45+1'");
      // Somewhere in the break.
      expect([for (var s = 225.0; s < 300; s += 5) at(s)], contains('HT'));
      expect(scores.clock(f.id, scores.endOf(f.id)!), 'FT');
    });

    test('scores are in the range football scores are in', () {
      final goals = [
        for (final m in finals<FootballSnapshot>()) ...[
          m.homeGoals,
          m.awayGoals,
        ],
      ];
      final mean = goals.reduce((a, b) => a + b) / goals.length;
      expect(mean, inInclusiveRange(.8, 2.4));
      expect(goals.every((g) => g <= 8), isTrue);
    });
  });

  group('basketball', () {
    test('quarters, box score and total all agree', () {
      for (final m in finals<BasketballSnapshot>()) {
        expect(
          m.byPeriod.fold(0, (s, q) => s + q.$1),
          m.homePoints,
          reason: m.id,
        );
        expect(m.byPeriod.fold(0, (s, q) => s + q.$2), m.awayPoints);
        for (final s in Side.values) {
          expect(m.box(s).fold(0, (sum, l) => sum + l.points), m.points(s));
          for (final l in m.box(s)) {
            expect(l.made, lessThanOrEqualTo(l.attempts));
            expect(l.threes, lessThanOrEqualTo(l.made));
          }
        }
      }
    });

    test('nobody draws: a level game goes to overtime', () {
      for (final m in finals<BasketballSnapshot>()) {
        expect(m.homePoints, isNot(m.awayPoints), reason: m.id);
        expect(m.leader, isNotNull);
        expect(m.byPeriod.length, m.periods);
        expect(m.periods, greaterThanOrEqualTo(BasketballSnapshot.regulation));
      }
    });

    test('the lead tracker ends on the final margin', () {
      for (final m in finals<BasketballSnapshot>()) {
        expect(m.lead.last.margin, m.homePoints - m.awayPoints);
        expect(m.lead.last.at, inInclusiveRange(0, 1));
        expect(m.progress, 1);
        final (h, a) = m.biggestLead;
        expect(h, greaterThanOrEqualTo(0));
        expect(a, greaterThanOrEqualTo(0));
      }
    });

    test('the clock counts a quarter down', () {
      final f = fixtureIn(scores, Sport.basketball, Phase.upcoming);
      String at(int seconds) =>
          scores.clock(f.id, f.kickoff.add(Duration(seconds: seconds)));
      expect(at(0), 'Q1 12:00');
      expect(at(50), startsWith('Q1 '));
      expect(at(110), 'End Q1');
      expect(at(125), startsWith('Q2 '));
      expect(scores.clock(f.id, scores.endOf(f.id)!), 'Final');
    });
  });

  group('cricket', () {
    test('the total is the runs off the bat and the extras', () {
      for (final m in finals<CricketSnapshot>()) {
        expect(m.innings.length, 2, reason: m.id);
        for (final i in m.innings) {
          final bat = i.batters.fold(0, (s, b) => s + b.runs);
          expect(bat + i.extras, i.runs, reason: m.id);
          expect(i.bowlers.fold(0, (s, b) => s + b.runs), i.runs);
          expect(i.bowlers.fold(0, (s, b) => s + b.balls), i.balls);
          expect(i.balls, lessThanOrEqualTo(CricketSnapshot.ballsPerSide));
          expect(i.wickets, lessThanOrEqualTo(10));
          expect(i.wickets, i.fallOfWickets.length);
          expect(i.byOver.last, i.runs);
          expect(i.closed, isTrue);
        }
      }
    });

    test('no bowler bowls more than four overs', () {
      for (final m in finals<CricketSnapshot>()) {
        for (final i in m.innings) {
          for (final b in i.bowlers) {
            expect(
              b.balls,
              lessThanOrEqualTo(24),
              reason: '${m.id} ${b.player.name}',
            );
          }
        }
      }
    });

    test('a chase stops the moment the target is passed', () {
      for (final m in finals<CricketSnapshot>()) {
        final first = m.innings.first, second = m.innings.last;
        if (second.runs > first.runs) {
          // At most six runs past: the winning hit.
          expect(second.runs - first.runs, lessThanOrEqualTo(6));
          expect(m.headline, contains('wicket'));
        } else if (second.runs < first.runs) {
          expect(
            second.wickets == 10 ||
                second.balls == CricketSnapshot.ballsPerSide,
            isTrue,
            reason: m.id,
          );
          expect(m.headline, contains('run'));
        }
      }
    });

    test('only the two at the crease are batting', () {
      final f = fixtureIn(scores, Sport.cricket, Phase.upcoming);
      final m =
          scores.match(f.id, f.kickoff.add(const Duration(seconds: 90)))!
              as CricketSnapshot;
      final batting = m.current!.batters.where(
        (b) => b.state == BatterState.batting,
      );
      expect(batting.length, 2);
      expect(batting.where((b) => b.onStrike).length, 1);
      expect(m.current!.bowlers.where((b) => b.bowling).length, 1);
      expect(m.thisOver.length, lessThanOrEqualTo(12));
      expect(
        scores.clock(f.id, f.kickoff.add(const Duration(seconds: 90))),
        endsWith(' ov'),
      );
    });

    test('overs read as overs and balls', () {
      expect(oversText(0), '0.0');
      expect(oversText(87), '14.3');
      expect(oversText(120), '20.0');
    });
  });

  group('tables', () {
    test('are added up from results, and add up', () {
      for (final c in scores.competitions) {
        final rows = scores.table(c.id, testNow);
        expect(rows.length, c.teamIds.length);
        expect(
          [for (final r in rows) r.position],
          [for (var i = 1; i <= rows.length; i++) i],
        );
        // Every match is played by two teams.
        expect(rows.fold(0, (s, r) => s + r.played).isEven, isTrue);
        expect(
          rows.fold(0, (s, r) => s + r.won),
          rows.fold(0, (s, r) => s + r.lost),
        );
        expect(
          rows.fold(0, (s, r) => s + r.scored),
          rows.fold(0, (s, r) => s + r.conceded),
        );
        for (final r in rows) {
          expect(r.won + r.drawn + r.lost, r.played);
          expect(r.form.length, lessThanOrEqualTo(5));
          if (c.sport == Sport.football) {
            expect(r.points, 3 * r.won + r.drawn);
          }
        }
        expect(
          TableStyle.of(c.sport).cells(rows.first).length,
          TableStyle.of(c.sport).columns.length,
        );
      }
    });

    test('are in order', () {
      for (final c in scores.competitions) {
        final rows = scores.table(c.id, testNow);
        for (var i = 1; i < rows.length; i++) {
          if (c.sport == Sport.basketball) {
            expect(
              rows[i - 1].winShare,
              greaterThanOrEqualTo(rows[i].winShare),
            );
          } else {
            expect(rows[i - 1].points, greaterThanOrEqualTo(rows[i].points));
          }
        }
      }
    });

    test('move when a match ends', () {
      final f = fixtureIn(scores, Sport.football, Phase.live);
      final end = scores.endOf(f.id)!;
      int played(DateTime at) => scores
          .table(f.competitionId, at)
          .firstWhere((r) => r.team.id == f.homeId)
          .played;
      final before = played(end.subtract(const Duration(seconds: 1)));
      expect(played(end), before + 1);
      // And the same list comes back while nothing has changed.
      expect(
        identical(
          scores.table(f.competitionId, testNow),
          scores.table(
            f.competitionId,
            testNow.add(const Duration(seconds: 1)),
          ),
        ),
        isTrue,
      );
    });

    test('a team has a full season of fixtures, one a round', () {
      final c = scores.competitions.first;
      final season = scores.seasonOf(c.teamIds.first, testNow);
      expect(season.length, 2 * (c.teamIds.length - 1));
      expect(season.map((f) => f.round).toSet().length, season.length);
    });
  });
}
