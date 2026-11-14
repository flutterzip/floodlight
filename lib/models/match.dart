import 'package:flutter/foundation.dart';

import 'fixture.dart';
import 'league.dart';

enum MatchStage {
  upcoming,
  live,

  /// Half time, a quarter break, the change of innings.
  paused,
  finished;

  bool get inPlay => this == live || this == paused;
}

/// What a scoreboard shows for one side: the number, and for cricket the
/// overs beside it.
@immutable
class ScoreLine {
  const ScoreLine(this.main, [this.detail = '']);

  /// "2", "98", "164/5", or empty when a side has not batted.
  final String main;

  /// "(18.2)" in cricket, otherwise empty.
  final String detail;

  static const none = ScoreLine('');
}

/// The chance of each outcome, adding up to one. [draw] is zero where a
/// sport has none.
@immutable
class WinChance {
  const WinChance({required this.home, required this.draw, required this.away});

  const WinChance.even() : home = .5, draw = 0, away = .5;

  final double home;
  final double draw;
  final double away;

  double of(Side side) => side == Side.home ? home : away;
}

enum FeedKind {
  /// A goal, a basket that matters, a boundary.
  score,
  wicket,
  card,
  change,

  /// A whistle: the start, a break, the end.
  period,
  note,
}

/// One line of the running commentary.
@immutable
class FeedItem {
  const FeedItem({
    required this.id,
    required this.at,
    required this.clock,
    required this.kind,
    required this.title,
    this.detail = '',
    this.side,
    this.major = false,
    this.badge = '',
  });

  final String id;

  /// How long after the start it happened, in real time.
  final Duration at;

  /// "67'", "Q3 4:12", "14.3".
  final String clock;
  final FeedKind kind;
  final String title;
  final String detail;
  final Side? side;

  /// Shown in the summary as well as the full feed, and worth an alert.
  final bool major;

  /// A short mark for the line's bullet: "4", "6", "W", "3".
  final String badge;
}

/// One row of the head-to-head statistics.
@immutable
class StatPair {
  const StatPair(
    this.label,
    this.home,
    this.away, {
    this.suffix = '',
    this.places = 0,
  });

  final String label;
  final double home;
  final double away;
  final String suffix;

  /// Decimal places to show.
  final int places;

  String text(Side side) =>
      '${(side == Side.home ? home : away).toStringAsFixed(places)}$suffix';

  /// The home side's share of the pair, for the bar.
  double get share {
    final sum = home + away;
    return sum <= 0 ? .5 : home / sum;
  }
}

/// What a finished match adds to the table.
typedef Tally = ({
  num home,
  num away,

  /// Cricket only: legal balls each side faced, for net run rate. An
  /// innings that ends all out counts as the full allocation.
  int homeBalls,
  int awayBalls,
});

/// A match at one moment. Built by the sport's engine from the fixture and
/// the time elapsed; never stored.
abstract class MatchSnapshot {
  const MatchSnapshot({
    required this.fixture,
    required this.home,
    required this.away,
    required this.stage,
    required this.revision,
  });

  final Fixture fixture;
  final Team home;
  final Team away;
  final MatchStage stage;

  /// How many things have happened so far. Two snapshots of one match with
  /// the same revision are the same snapshot.
  final int revision;

  Sport get sport => fixture.sport;
  String get id => fixture.id;
  Team team(Side side) => side == Side.home ? home : away;

  ScoreLine score(Side side);

  /// "Second half", "Half time", "Innings break", "Full time".
  String get status;

  /// The short form for a list row: "HT", "FT", "Q3", "2nd inns".
  String get shortStatus;

  /// The line under a finished or running score: "Northgate won 2-1",
  /// "Kano need 34 from 21 balls".
  String get headline;

  /// The side in front right now, or the winner once it is over.
  Side? get leader;

  WinChance get chance;

  /// Oldest first.
  List<FeedItem> get feed;

  List<StatPair> get stats;

  Tally get tally;

  /// Counts the moments worth a flourish on the scoreboard.
  int get scoringMoments;
}
