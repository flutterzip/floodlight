import 'package:flutter/foundation.dart';

import 'league.dart';

enum Outcome { win, draw, loss }

/// One team's row in a league table. Never stored: it is added up from the
/// season's finished matches, so a table can not disagree with a result.
@immutable
class StandingRow {
  const StandingRow({
    required this.team,
    required this.position,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.scored,
    required this.conceded,
    required this.points,
    required this.form,
    this.netRunRate = 0,
    this.playing = false,
  });

  final Team team;

  /// From 1.
  final int position;
  final int played;
  final int won;
  final int drawn;
  final int lost;

  /// Goals, points or runs for and against.
  final int scored;
  final int conceded;
  final int points;

  /// The last five results, oldest first.
  final List<Outcome> form;

  /// Cricket only.
  final double netRunRate;

  /// The team has a match under way right now.
  final bool playing;

  int get difference => scored - conceded;
  double get winShare => played == 0 ? 0 : won / played;
}

/// What a sport's table shows beside the team, and how it is ordered.
enum TableStyle {
  football(['P', 'W', 'D', 'L', 'GD', 'Pts']),
  basketball(['P', 'W', 'L', 'Pct', 'Diff']),
  cricket(['P', 'W', 'L', 'NRR', 'Pts']);

  const TableStyle(this.columns);
  final List<String> columns;

  static TableStyle of(Sport sport) => switch (sport) {
    Sport.football => football,
    Sport.basketball => basketball,
    Sport.cricket => cricket,
  };

  List<String> cells(StandingRow r) {
    String signed(num v, [int places = 0]) =>
        '${v > 0 ? '+' : ''}${v.toStringAsFixed(places)}';
    return switch (this) {
      football => [
        '${r.played}',
        '${r.won}',
        '${r.drawn}',
        '${r.lost}',
        signed(r.difference),
        '${r.points}',
      ],
      basketball => [
        '${r.played}',
        '${r.won}',
        '${r.lost}',
        r.winShare.toStringAsFixed(3).replaceFirst('0.', '.'),
        signed(r.difference),
      ],
      cricket => [
        '${r.played}',
        '${r.won}',
        '${r.lost}',
        signed(r.netRunRate, 2),
        '${r.points}',
      ],
    };
  }
}
