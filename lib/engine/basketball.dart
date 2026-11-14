import 'dart:math' as math;

import '../models/basketball.dart';
import '../models/league.dart';
import '../models/match.dart';
import 'chance.dart';
import 'match_script.dart';
import 'rng.dart';

enum _PlayKind { two, three, freeThrows, miss, turnover }

sealed class _Step {
  const _Step(this.period);
  final int period;
}

class _Tip extends _Step {
  const _Tip(super.period);
}

class _Horn extends _Step {
  const _Horn(super.period);
}

class _Play extends _Step {
  const _Play(
    super.period, {
    required this.left,
    required this.side,
    required this.kind,
    required this.playerId,
    this.points = 0,
    this.assistId = '',
    this.reboundId = '',
    this.reboundSide,
    this.three = false,
  });

  /// Game seconds left in the period.
  final double left;
  final Side side;
  final _PlayKind kind;
  final String playerId;
  final int points;
  final String assistId;
  final String reboundId;
  final Side? reboundSide;

  /// A missed shot from beyond the arc.
  final bool three;
}

typedef _Period = ({double start, double length, double end});

/// Four quarters, and overtime for as long as it is level, played once
/// from the fixture's seed.
///
/// Twelve minutes of game time take [quarterSeconds] real seconds, so a
/// game lasts about eight and a half minutes.
class BasketballScript extends MatchScript<BasketballSnapshot> {
  BasketballScript(super.fixture, super.home, super.away) {
    _play();
  }

  static const quarterSeconds = 105.0;
  static const _quarter = 720.0;
  static const _overtime = 300.0;
  static const _scale = quarterSeconds / _quarter;
  static const _shortBreak = 14.0;
  static const _halfTime = 30.0;

  final _steps = <_Step>[];
  final _at = <Duration>[];
  final _periods = <_Period>[];
  late final double _edgePoints;

  @override
  List<Duration> get offsets => _at;

  double get _gameSeconds => _periods.fold(0, (sum, p) => sum + p.length);

  List<Player> _five(Side side, int period, double t) {
    final squad = (side == Side.home ? home : away).squad;
    final five = squad.take(5).toList();
    final bench = squad.skip(5).toList();
    if (period > BasketballSnapshot.regulation) return five;
    if (period.isOdd && t >= 450) {
      for (var i = 0; i < 2 && i < bench.length; i++) {
        five[3 + i] = bench[i];
      }
    } else if (period.isEven && t < 300) {
      for (var i = 0; i < 3 && i < bench.length; i++) {
        five[2 + i] = bench[i];
      }
    }
    return five;
  }

  void _play() {
    final rng = Rng.of(fixture.id);
    final edge = (home.rating + 3 - away.rating) / 100;
    _edgePoints = (home.rating - away.rating) * .5 + 2;
    var real = 0.0;
    var score = 0;
    var ball = rng.chance(.5) ? Side.home : Side.away;

    void add(double at, _Step step) {
      _at.add(realTime(at));
      _steps.add(step);
    }

    for (var period = 1; ; period++) {
      final length = period <= BasketballSnapshot.regulation
          ? _quarter
          : _overtime;
      final start = real;
      add(start, _Tip(period));
      var t = 0.0;
      while (true) {
        t += 7 + rng.d() * 15;
        if (t >= length) break;
        final five = _five(ball, period, t);
        final e = ball == Side.home ? edge : -edge;
        final at = start + t * _scale;
        final r = rng.d();
        final shooter = rng.weighted(
          five,
          (p) => math.pow(p.rating / 70, 3) + .0,
        );
        if (r < .125 - e * .04) {
          add(
            at,
            _Play(
              period,
              left: length - t,
              side: ball,
              kind: _PlayKind.turnover,
              playerId: rng.pick(five).id,
            ),
          );
          ball = ball.other;
        } else if (r < .215) {
          var made = 0;
          for (var i = 0; i < 2; i++) {
            if (rng.chance((.77 * shooter.rating / 78).clamp(.5, .93))) made++;
          }
          add(
            at,
            _Play(
              period,
              left: length - t,
              side: ball,
              kind: _PlayKind.freeThrows,
              playerId: shooter.id,
              points: made,
            ),
          );
          score += ball == Side.home ? made : -made;
          ball = ball.other;
        } else {
          final three = rng.chance(shooter.role == 'C' ? .12 : .4);
          // The side's edge moves the chance a little; the shooter's own
          // quality moves it a little more.
          final p =
              ((three ? .355 : .525) + e * .06 + (shooter.rating - 78) * .0012)
                  .clamp(.2, .7);
          if (rng.chance(p)) {
            final mates = [
              for (final m in five)
                if (m.id != shooter.id) m,
            ];
            final points = three ? 3 : 2;
            add(
              at,
              _Play(
                period,
                left: length - t,
                side: ball,
                kind: three ? _PlayKind.three : _PlayKind.two,
                playerId: shooter.id,
                points: points,
                assistId: rng.chance(.62)
                    ? rng.weighted(mates, (m) => m.role == 'G' ? 2.5 : 1.0).id
                    : '',
              ),
            );
            score += ball == Side.home ? points : -points;
            ball = ball.other;
          } else {
            final defensive = rng.chance(.73);
            final boards = defensive ? ball.other : ball;
            final rebounder = rng.weighted(
              _five(boards, period, t),
              (m) => switch (m.role) {
                'C' => 3.2,
                'F' => 2.0,
                _ => 1.0,
              },
            );
            add(
              at,
              _Play(
                period,
                left: length - t,
                side: ball,
                kind: _PlayKind.miss,
                playerId: shooter.id,
                three: three,
                reboundId: rebounder.id,
                reboundSide: boards,
              ),
            );
            if (defensive) ball = ball.other;
          }
        }
      }
      final end = start + length * _scale;
      add(end, _Horn(period));
      _periods.add((start: start, length: length, end: end));
      final last = period >= BasketballSnapshot.regulation && score != 0;
      if (last) break;
      real = end + (period == 2 ? _halfTime : _shortBreak);
    }
  }

  /// The period under way or just finished at [seconds], and whether play
  /// is stopped.
  (int period, bool playing) _where(double seconds) {
    for (var i = 0; i < _periods.length; i++) {
      final p = _periods[i];
      if (seconds < p.end) return (i + 1, seconds >= p.start);
      if (i + 1 < _periods.length && seconds < _periods[i + 1].start) {
        return (i + 1, false);
      }
    }
    return (_periods.length, false);
  }

  @override
  bool pausedAt(Duration elapsed) => !_where(elapsed.inMicroseconds / 1e6).$2;

  @override
  String clockAt(Duration elapsed) {
    final s = elapsed.inMicroseconds / 1e6;
    if (s < 0) return '';
    if (elapsed >= length) return 'Final';
    final (period, playing) = _where(s);
    final name = BasketballSnapshot.periodName(period);
    if (!playing) return period == 2 ? 'Half' : 'End $name';
    final p = _periods[period - 1];
    final left = (p.length - (s - p.start) / _scale).clamp(0, p.length).ceil();
    return '$name ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
  }

  static String _clock(int period, double left) {
    final l = left.ceil();
    return '${BasketballSnapshot.periodName(period)} '
        '${l ~/ 60}:${(l % 60).toString().padLeft(2, '0')}';
  }

  @override
  BasketballSnapshot build(int count, MatchStage stage) {
    final points = {Side.home: 0, Side.away: 0};
    final byPeriod = <(int, int)>[];
    // made, attempts, threes made, threes tried, free throws made and tried,
    // rebounds, assists, turnovers.
    final team = {for (final s in Side.values) s: List<int>.filled(9, 0)};
    final lines = <String, List<int>>{}; // pts, reb, ast, made, att, threes
    List<int> of(String id) => lines.putIfAbsent(id, () => List.filled(6, 0));
    final lead = <LeadPoint>[(at: 0, margin: 0)];
    final feed = <FeedItem>[];
    var period = 1, paused = false;
    var played = 0.0, before = 0.0, lastLeft = 0.0;
    var lastLeader = 0, changes = 0, bigHome = 0, bigAway = 0;
    Side? runSide;
    var runPoints = 0;
    String name(Side side, String id) =>
        this.team(side).player(id)?.shortName ?? '';
    String line() =>
        '${home.short} ${points[Side.home]}-'
        '${points[Side.away]} ${away.short}';

    for (var i = 0; i < count; i++) {
      final step = _steps[i];
      switch (step) {
        case _Tip():
          period = step.period;
          paused = false;
          byPeriod.add((0, 0));
          lastLeft = _periods.length >= period
              ? _periods[period - 1].length
              : _quarter;
          if (period == 1) {
            feed.add(
              FeedItem(
                id: 't$i',
                at: _at[i],
                clock: 'Q1 12:00',
                kind: FeedKind.period,
                title: 'Tip-off',
                detail: home.ground,
                major: true,
              ),
            );
          }
        case _Horn():
          paused = true;
          before += _periods[period - 1].length;
          played = before;
          lastLeft = 0;
          final name = BasketballSnapshot.periodName(period);
          feed.add(
            FeedItem(
              id: 'h$i',
              at: _at[i],
              clock: name,
              kind: FeedKind.period,
              title: i == _steps.length - 1
                  ? 'Final'
                  : period == 2
                  ? 'Half time'
                  : 'End of $name',
              detail: line(),
              major: true,
            ),
          );
        case _Play():
          final s = step.side;
          final t = team[s]!;
          final l = of(step.playerId);
          lastLeft = step.left;
          played = before + _periods[period - 1].length - step.left;
          switch (step.kind) {
            case _PlayKind.turnover:
              t[8]++;
            case _PlayKind.miss:
              t[1]++;
              l[4]++;
              if (step.three) t[3]++;
              team[step.reboundSide!]![6]++;
              of(step.reboundId)[1]++;
            case _PlayKind.freeThrows:
              t[4] += step.points;
              t[5] += 2;
              l[0] += step.points;
            case _PlayKind.two || _PlayKind.three:
              final three = step.kind == _PlayKind.three;
              t[0]++;
              t[1]++;
              l[0] += step.points;
              l[3]++;
              l[4]++;
              if (three) {
                t[2]++;
                t[3]++;
                l[5]++;
              }
              if (step.assistId.isNotEmpty) {
                t[7]++;
                of(step.assistId)[2]++;
              }
          }
          if (step.points > 0) {
            points[s] = points[s]! + step.points;
            final (h, a) = byPeriod.last;
            byPeriod.last = s == Side.home
                ? (h + step.points, a)
                : (h, a + step.points);
            final margin = points[Side.home]! - points[Side.away]!;
            lead.add((at: played / _gameSeconds, margin: margin));
            if (margin != 0 && margin.sign != lastLeader) {
              if (lastLeader != 0) changes++;
              lastLeader = margin.sign;
            }
            bigHome = math.max(bigHome, margin);
            bigAway = math.max(bigAway, -margin);
            if (runSide == s) {
              runPoints += step.points;
            } else {
              runSide = s;
              runPoints = step.points;
            }
            feed.add(
              FeedItem(
                id: 'p$i',
                at: _at[i],
                clock: _clock(period, step.left),
                kind: FeedKind.score,
                side: s,
                badge: '${step.points}',
                title: switch (step.kind) {
                  _PlayKind.three => '${name(s, step.playerId)} hits a three',
                  _PlayKind.freeThrows =>
                    '${name(s, step.playerId)} makes ${step.points} of 2 at the line',
                  _ => '${name(s, step.playerId)} scores inside',
                },
                detail: step.assistId.isEmpty
                    ? line()
                    : '${line()}. Assist ${name(s, step.assistId)}',
              ),
            );
          }
      }
    }

    final finished = stage == MatchStage.finished;
    final margin = points[Side.home]! - points[Side.away]!;
    final regulation = BasketballSnapshot.regulation * _quarter;
    final toPlay = math.max(_gameSeconds - played, 0) / regulation;
    final courtTime = _periods.length >= period
        ? _periods[period - 1].length - lastLeft
        : 0.0;
    List<BoxLine> box(Side side) {
      final squad = this.team(side).squad;
      final on = {for (final p in _five(side, period, courtTime)) p.id};
      return [
        for (var i = 0; i < squad.length; i++)
          () {
            final l = lines[squad[i].id] ?? const [0, 0, 0, 0, 0, 0];
            return BoxLine(
              player: squad[i],
              starter: i < 5,
              points: l[0],
              rebounds: l[1],
              assists: l[2],
              made: l[3],
              attempts: l[4],
              threes: l[5],
              onCourt: stage.inPlay && on.contains(squad[i].id),
            );
          }(),
      ];
    }

    double pct(int made, int tried) => tried == 0 ? 0 : 100 * made / tried;
    final h = team[Side.home]!, a = team[Side.away]!;
    StatPair share(String label, int made, int tried) => StatPair(
      label,
      pct(h[made], h[tried]),
      pct(a[made], a[tried]),
      suffix: '%',
    );
    StatPair total(String label, int at) =>
        StatPair(label, h[at] + .0, a[at] + .0);

    return BasketballSnapshot(
      fixture: fixture,
      home: home,
      away: away,
      stage: stage,
      revision: count,
      period: period,
      periods: _periods.length,
      homePoints: points[Side.home]!,
      awayPoints: points[Side.away]!,
      byPeriod: byPeriod,
      homeBox: box(Side.home),
      awayBox: box(Side.away),
      lead: lead,
      progress: (played / _gameSeconds).clamp(0, 1),
      leadChanges: changes,
      biggestLead: (bigHome, bigAway),
      run: !finished && runSide != null && runPoints >= 7
          ? (side: runSide, points: runPoints)
          : null,
      paused: paused && !finished,
      feed: feed,
      chance: finished
          ? WinChance(
              home: margin > 0 ? 1 : 0,
              draw: 0,
              away: margin > 0 ? 0 : 1,
            )
          : marginChance(
              expected: margin + _edgePoints * toPlay,
              spread: 12.5 * math.sqrt(toPlay) + .7,
            ),
      stats: [
        share('Field goals', 0, 1),
        share('Three pointers', 2, 3),
        share('Free throws', 4, 5),
        total('Rebounds', 6),
        total('Assists', 7),
        total('Turnovers', 8),
        StatPair('Biggest lead', bigHome + .0, bigAway + .0),
      ],
    );
  }
}
