import 'package:flutter/foundation.dart';

import 'league.dart';
import 'match.dart';

/// One player's line in the box score.
@immutable
class BoxLine {
  const BoxLine({
    required this.player,
    required this.starter,
    this.points = 0,
    this.rebounds = 0,
    this.assists = 0,
    this.made = 0,
    this.attempts = 0,
    this.threes = 0,
    this.onCourt = false,
  });

  final Player player;
  final bool starter;
  final int points;
  final int rebounds;
  final int assists;

  /// Field goals made and attempted.
  final int made;
  final int attempts;
  final int threes;
  final bool onCourt;
}

/// The margin at one moment, for the lead tracker. [at] runs 0 to 1 through
/// the game; [margin] is above zero when the home side leads.
typedef LeadPoint = ({double at, int margin});

class BasketballSnapshot extends MatchSnapshot {
  const BasketballSnapshot({
    required super.fixture,
    required super.home,
    required super.away,
    required super.stage,
    required super.revision,
    required this.period,
    required this.periods,
    required this.homePoints,
    required this.awayPoints,
    required this.byPeriod,
    required this.homeBox,
    required this.awayBox,
    required this.lead,
    required this.progress,
    required this.leadChanges,
    required this.biggestLead,
    required this.run,
    required this.feed,
    required this.stats,
    required this.chance,
    required this.paused,
  });

  /// The period being played, from 1. Above [regulation] is overtime.
  final int period;

  /// How many periods the game has in all, overtime included.
  final int periods;
  final int homePoints;
  final int awayPoints;

  /// Points in each period so far: home, then away.
  final List<(int, int)> byPeriod;
  final List<BoxLine> homeBox;
  final List<BoxLine> awayBox;
  final List<LeadPoint> lead;

  /// How far through the game play has reached, 0 to 1.
  final double progress;
  final int leadChanges;

  /// The largest lead each side has held: home, then away.
  final (int, int) biggestLead;

  /// An unanswered scoring run under way, if there is one worth naming.
  final ({Side side, int points})? run;
  final bool paused;

  static const regulation = 4;

  @override
  final List<FeedItem> feed;

  @override
  final List<StatPair> stats;

  @override
  final WinChance chance;

  int points(Side side) => side == Side.home ? homePoints : awayPoints;
  List<BoxLine> box(Side side) => side == Side.home ? homeBox : awayBox;

  static String periodName(int period) => period <= regulation
      ? 'Q$period'
      : period == regulation + 1
      ? 'OT'
      : 'OT${period - regulation}';

  @override
  ScoreLine score(Side side) => stage == MatchStage.upcoming
      ? ScoreLine.none
      : ScoreLine('${points(side)}');

  @override
  String get status {
    if (stage == MatchStage.upcoming) return 'Tip-off';
    if (stage == MatchStage.finished) {
      return periods > regulation ? 'Final, overtime' : 'Final';
    }
    if (paused) {
      return period == 2 ? 'Half time' : 'End of ${periodName(period)}';
    }
    return switch (period) {
      1 => 'First quarter',
      2 => 'Second quarter',
      3 => 'Third quarter',
      4 => 'Fourth quarter',
      _ => 'Overtime',
    };
  }

  @override
  String get shortStatus {
    if (stage == MatchStage.upcoming) return '';
    if (stage == MatchStage.finished) {
      return periods > regulation ? 'F/OT' : 'Final';
    }
    if (paused && period == 2) return 'Half';
    return periodName(period);
  }

  @override
  Side? get leader => homePoints == awayPoints
      ? null
      : homePoints > awayPoints
      ? Side.home
      : Side.away;

  @override
  String get headline {
    final l = leader;
    if (stage == MatchStage.upcoming) return '${home.ground}, ${home.city}';
    if (l == null) return 'Tied at $homePoints';
    final margin = (homePoints - awayPoints).abs();
    if (stage == MatchStage.finished) {
      return '${team(l).name} won by $margin';
    }
    final r = run;
    if (r != null) return '${team(r.side).name} are on a ${r.points}-0 run';
    return '${team(l).name} lead by $margin';
  }

  @override
  Tally get tally =>
      (home: homePoints, away: awayPoints, homeBalls: 0, awayBalls: 0);

  @override
  int get scoringMoments => homePoints + awayPoints;
}
