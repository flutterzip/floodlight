import 'package:flutter/foundation.dart';

import 'league.dart';
import 'match.dart';

enum BatterState { yetToBat, batting, out }

@immutable
class BatterLine {
  const BatterLine({
    required this.player,
    required this.state,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.dismissal = '',
    this.onStrike = false,
  });

  final Player player;
  final BatterState state;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;

  /// "c Bello b Rahman", "run out", or "not out".
  final String dismissal;
  final bool onStrike;

  double get strikeRate => balls == 0 ? 0 : 100 * runs / balls;
}

@immutable
class BowlerLine {
  const BowlerLine({
    required this.player,
    this.balls = 0,
    this.maidens = 0,
    this.runs = 0,
    this.wickets = 0,
    this.bowling = false,
  });

  final Player player;

  /// Legal balls bowled.
  final int balls;
  final int maidens;
  final int runs;
  final int wickets;

  /// Bowling the current over.
  final bool bowling;

  String get overs => oversText(balls);
  double get economy => balls == 0 ? 0 : runs * 6 / balls;
}

/// "14.3" for 87 balls.
String oversText(int balls) => '${balls ~/ 6}.${balls % 6}';

/// One delivery as it shows in the over strip: "1", "4", "W", "wd", a dot.
@immutable
class BallMark {
  const BallMark(
    this.text, {
    this.boundary = false,
    this.wicket = false,
    this.extra = false,
  });

  final String text;
  final bool boundary;
  final bool wicket;
  final bool extra;
}

@immutable
class Innings {
  const Innings({
    required this.batting,
    required this.runs,
    required this.wickets,
    required this.balls,
    required this.extras,
    required this.batters,
    required this.bowlers,
    required this.fallOfWickets,
    required this.byOver,
    required this.closed,
  });

  final Side batting;
  final int runs;
  final int wickets;

  /// Legal balls bowled.
  final int balls;
  final int extras;
  final List<BatterLine> batters;
  final List<BowlerLine> bowlers;

  /// "42/1 (5.3)", in order.
  final List<String> fallOfWickets;

  /// The total at the end of each over so far (the last may be part way).
  final List<int> byOver;
  final bool closed;

  String get overs => oversText(balls);
  double get runRate => balls == 0 ? 0 : runs * 6 / balls;
  String get total => '$runs/$wickets';
}

class CricketSnapshot extends MatchSnapshot {
  const CricketSnapshot({
    required super.fixture,
    required super.home,
    required super.away,
    required super.stage,
    required super.revision,
    required this.innings,
    required this.thisOver,
    required this.partnership,
    required this.feed,
    required this.chance,
    required this.paused,
    required this.boundaries,
  });

  static const oversPerSide = 20;
  static const ballsPerSide = oversPerSide * 6;

  /// None before the start, then one, then two.
  final List<Innings> innings;

  /// The balls of the over in progress.
  final List<BallMark> thisOver;

  /// Runs and balls the pair at the crease have put on.
  final (int, int) partnership;
  final bool paused;
  final int boundaries;

  @override
  final List<FeedItem> feed;

  @override
  final WinChance chance;

  Innings? get current => innings.isEmpty ? null : innings.last;
  Innings? inningsOf(Side side) {
    for (final i in innings) {
      if (i.batting == side) return i;
    }
    return null;
  }

  int? get target => innings.length < 2 ? null : innings.first.runs + 1;
  bool get chasing => innings.length == 2;

  /// Runs still needed and balls left, during a chase.
  (int, int)? get needed {
    final t = target;
    if (t == null) return null;
    final i = innings.last;
    return (t - i.runs, ballsPerSide - i.balls);
  }

  double? get requiredRate {
    final n = needed;
    if (n == null || n.$2 <= 0) return null;
    return n.$1 * 6 / n.$2;
  }

  @override
  ScoreLine score(Side side) {
    final i = inningsOf(side);
    if (i == null) return ScoreLine.none;
    return ScoreLine(i.total, '(${i.overs})');
  }

  @override
  String get status {
    if (stage == MatchStage.upcoming) return 'Toss';
    if (stage == MatchStage.finished) return 'Result';
    if (paused) return 'Innings break';
    return chasing ? 'Second innings' : 'First innings';
  }

  @override
  String get shortStatus {
    if (stage == MatchStage.upcoming) return '';
    if (stage == MatchStage.finished) return 'Result';
    if (paused) return 'Break';
    return chasing ? '2nd inns' : '1st inns';
  }

  @override
  Side? get leader {
    if (innings.length < 2) return null;
    final first = innings.first, second = innings.last;
    if (stage == MatchStage.finished) {
      if (second.runs == first.runs) return null;
      return second.runs > first.runs ? second.batting : first.batting;
    }
    return chance.home == chance.away
        ? null
        : chance.home > chance.away
        ? Side.home
        : Side.away;
  }

  @override
  String get headline {
    if (stage == MatchStage.upcoming) return '${home.ground}, ${home.city}';
    final first = innings.first;
    if (innings.length == 1) {
      if (paused) {
        return '${team(first.batting.other).name} need ${first.runs + 1} to win';
      }
      return '${team(first.batting).name} batting first';
    }
    final second = innings.last;
    if (stage == MatchStage.finished) {
      if (second.runs > first.runs) {
        final left = 10 - second.wickets;
        return '${team(second.batting).name} won by $left '
            '${left == 1 ? 'wicket' : 'wickets'}';
      }
      if (second.runs == first.runs) return 'Match tied';
      final by = first.runs - second.runs;
      return '${team(first.batting).name} won by $by ${by == 1 ? 'run' : 'runs'}';
    }
    final (runs, balls) = needed!;
    return '${team(second.batting).name} need $runs from $balls '
        '${balls == 1 ? 'ball' : 'balls'}';
  }

  @override
  List<StatPair> get stats {
    StatPair of(String label, double Function(Innings) get, {int places = 0}) =>
        StatPair(
          label,
          switch (inningsOf(Side.home)) {
            final i? => get(i),
            null => 0,
          },
          switch (inningsOf(Side.away)) {
            final i? => get(i),
            null => 0,
          },
          places: places,
        );
    int sum(Innings i, int Function(BatterLine) get) =>
        i.batters.fold(0, (s, b) => s + get(b));
    return [
      of('Run rate', (i) => i.runRate, places: 2),
      of('Fours', (i) => sum(i, (b) => b.fours) + .0),
      of('Sixes', (i) => sum(i, (b) => b.sixes) + .0),
      of('Extras', (i) => i.extras + .0),
      of('Wickets lost', (i) => i.wickets + .0),
      of(
        'Highest score',
        (i) => i.batters.fold(0, (m, b) => b.runs > m ? b.runs : m) + .0,
      ),
    ];
  }

  @override
  Tally get tally {
    int runs(Side s) => inningsOf(s)?.runs ?? 0;
    // All out counts as the full twenty overs for net run rate.
    int balls(Side s) {
      final i = inningsOf(s);
      if (i == null) return 0;
      return i.wickets >= 10 ? ballsPerSide : i.balls;
    }

    return (
      home: runs(Side.home),
      away: runs(Side.away),
      homeBalls: balls(Side.home),
      awayBalls: balls(Side.away),
    );
  }

  @override
  int get scoringMoments =>
      boundaries + innings.fold(0, (s, i) => s + i.wickets);
}
