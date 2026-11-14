import 'package:flutter/foundation.dart';

import 'league.dart';
import 'match.dart';

enum FootballPeriod { preMatch, firstHalf, halfTime, secondHalf, fullTime }

enum FootballEventKind {
  goal,
  saved,
  offTarget,
  blocked,
  corner,
  foul,
  yellow,
  red,
  offside,
  substitution,
}

@immutable
class FootballEvent {
  const FootballEvent({
    required this.kind,
    required this.side,
    required this.minute,
    required this.added,
    this.playerId = '',
    this.otherId = '',
    this.xg = 0,
  });

  final FootballEventKind kind;
  final Side side;

  /// 1 to 45 or 46 to 90, with [added] minutes of stoppage on top.
  final int minute;
  final int added;

  /// The scorer, the shooter, the player booked, or the player coming on.
  final String playerId;

  /// The assist, or the player going off.
  final String otherId;

  /// How good the chance was, 0 to 1.
  final double xg;

  String get clock => added > 0 ? "$minute+$added'" : "$minute'";
}

/// A player's place on the pitch and what has happened to them.
@immutable
class LineupSpot {
  const LineupSpot({
    required this.player,
    required this.x,
    required this.y,
    this.goals = 0,
    this.yellow = false,
    this.red = false,
    this.replacedBy,
  });

  final Player player;

  /// 0 to 1 across the pitch and 0 (own goal line) to 1 (halfway).
  final double x;
  final double y;
  final int goals;
  final bool yellow;
  final bool red;

  /// Who came on for them, if anyone.
  final Player? replacedBy;
}

class FootballSnapshot extends MatchSnapshot {
  const FootballSnapshot({
    required super.fixture,
    required super.home,
    required super.away,
    required super.stage,
    required super.revision,
    required this.period,
    required this.homeGoals,
    required this.awayGoals,
    required this.minute,
    required this.events,
    required this.feed,
    required this.stats,
    required this.momentum,
    required this.totalMinutes,
    required this.homeLineup,
    required this.awayLineup,
    required this.homeBench,
    required this.awayBench,
    required this.chance,
  });

  final FootballPeriod period;
  final int homeGoals;
  final int awayGoals;

  /// Minutes played, stoppage included.
  final int minute;
  final List<FootballEvent> events;

  /// Who was on top in each minute so far: above zero for the home side.
  final List<double> momentum;

  /// How many minutes the match will have in all, so a chart can leave
  /// room for the ones still to come.
  final int totalMinutes;
  final List<LineupSpot> homeLineup;
  final List<LineupSpot> awayLineup;
  final List<Player> homeBench;
  final List<Player> awayBench;

  @override
  final List<FeedItem> feed;

  @override
  final List<StatPair> stats;

  @override
  final WinChance chance;

  int goals(Side side) => side == Side.home ? homeGoals : awayGoals;

  Iterable<FootballEvent> get goalEvents =>
      events.where((e) => e.kind == FootballEventKind.goal);

  @override
  ScoreLine score(Side side) => stage == MatchStage.upcoming
      ? ScoreLine.none
      : ScoreLine('${goals(side)}');

  @override
  String get status => switch (period) {
    FootballPeriod.preMatch => 'Kick-off',
    FootballPeriod.firstHalf => 'First half',
    FootballPeriod.halfTime => 'Half time',
    FootballPeriod.secondHalf => 'Second half',
    FootballPeriod.fullTime => 'Full time',
  };

  @override
  String get shortStatus => switch (period) {
    FootballPeriod.preMatch => '',
    FootballPeriod.firstHalf => '1H',
    FootballPeriod.halfTime => 'HT',
    FootballPeriod.secondHalf => '2H',
    FootballPeriod.fullTime => 'FT',
  };

  @override
  Side? get leader => homeGoals == awayGoals
      ? null
      : homeGoals > awayGoals
      ? Side.home
      : Side.away;

  @override
  String get headline {
    final lead = leader;
    if (stage == MatchStage.upcoming) return '${home.ground}, ${home.city}';
    if (stage == MatchStage.finished) {
      if (lead == null) return 'Drawn $homeGoals-$awayGoals';
      final w = team(lead);
      return '${w.name} won ${goals(lead)}-${goals(lead.other)}';
    }
    if (lead == null) {
      return homeGoals == 0
          ? 'Goalless so far'
          : 'Level at $homeGoals-$awayGoals';
    }
    return '${team(lead).name} lead ${goals(lead)}-${goals(lead.other)}';
  }

  @override
  Tally get tally =>
      (home: homeGoals, away: awayGoals, homeBalls: 0, awayBalls: 0);

  @override
  int get scoringMoments => homeGoals + awayGoals;
}
