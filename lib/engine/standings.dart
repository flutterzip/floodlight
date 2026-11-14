import '../models/league.dart';
import '../models/match.dart';
import '../models/standing.dart';

class _Row {
  int played = 0, won = 0, drawn = 0, lost = 0;
  int scored = 0, conceded = 0, points = 0;
  int ballsFaced = 0, ballsBowled = 0;
  final form = <Outcome>[];
}

/// Adds finished matches up into a table. [finished] must be in the order
/// the matches were played, so the form guide reads oldest to newest.
List<StandingRow> buildTable({
  required Competition competition,
  required Map<String, Team> teams,
  required Iterable<MatchSnapshot> finished,
  Set<String> playing = const {},
}) {
  final rows = {for (final id in competition.teamIds) id: _Row()};
  final sport = competition.sport;
  final (win, draw) = switch (sport) {
    Sport.football => (3, 1),
    Sport.basketball => (1, 0),
    Sport.cricket => (2, 1),
  };

  for (final m in finished) {
    final t = m.tally;
    void credit(Side side) {
      final r = rows[m.fixture.teamId(side)];
      if (r == null) return;
      final mine = (side == Side.home ? t.home : t.away).toInt();
      final theirs = (side == Side.home ? t.away : t.home).toInt();
      r
        ..played += 1
        ..scored += mine
        ..conceded += theirs
        ..ballsFaced += side == Side.home ? t.homeBalls : t.awayBalls
        ..ballsBowled += side == Side.home ? t.awayBalls : t.homeBalls;
      if (mine > theirs) {
        r
          ..won += 1
          ..points += win
          ..form.add(Outcome.win);
      } else if (mine == theirs) {
        r
          ..drawn += 1
          ..points += draw
          ..form.add(Outcome.draw);
      } else {
        r
          ..lost += 1
          ..form.add(Outcome.loss);
      }
    }

    credit(Side.home);
    credit(Side.away);
  }

  double netRunRate(_Row r) => r.ballsFaced == 0 || r.ballsBowled == 0
      ? 0
      : r.scored * 6 / r.ballsFaced - r.conceded * 6 / r.ballsBowled;

  final order = rows.keys.toList()
    ..sort((a, b) {
      final x = rows[a]!, y = rows[b]!;
      int by(num p, num q) => q.compareTo(p);
      final c = switch (sport) {
        Sport.football => [
          by(x.points, y.points),
          by(x.scored - x.conceded, y.scored - y.conceded),
          by(x.scored, y.scored),
        ],
        Sport.basketball => [
          by(
            x.played == 0 ? 0 : x.won / x.played,
            y.played == 0 ? 0 : y.won / y.played,
          ),
          by(x.won, y.won),
          by(x.scored - x.conceded, y.scored - y.conceded),
        ],
        Sport.cricket => [
          by(x.points, y.points),
          by(netRunRate(x), netRunRate(y)),
        ],
      }.firstWhere((v) => v != 0, orElse: () => 0);
      return c != 0 ? c : teams[a]!.name.compareTo(teams[b]!.name);
    });

  return [
    for (var i = 0; i < order.length; i++)
      () {
        final r = rows[order[i]]!;
        final recent = r.form.length > 5
            ? r.form.sublist(r.form.length - 5)
            : r.form;
        return StandingRow(
          team: teams[order[i]]!,
          position: i + 1,
          played: r.played,
          won: r.won,
          drawn: r.drawn,
          lost: r.lost,
          scored: r.scored,
          conceded: r.conceded,
          points: r.points,
          form: List.unmodifiable(recent),
          netRunRate: netRunRate(r),
          playing: playing.contains(order[i]),
        );
      }(),
  ];
}
