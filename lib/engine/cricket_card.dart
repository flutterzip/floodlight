part of 'cricket.dart';

/// An innings being added up.
class _Card {
  _Card(this.batting, this.team, this.fielding);

  final Side batting;
  final Team team;
  final Team fielding;
  int runs = 0, wickets = 0, balls = 0, extras = 0;
  int pairRuns = 0, pairBalls = 0, ballInOver = 0;
  bool closed = false;
  String striker = '', partner = '', bowler = '';

  /// runs, balls, fours, sixes.
  final bat = <String, List<int>>{};
  final dismissed = <String, String>{};

  /// balls, maidens, runs, wickets.
  final bowl = <String, List<int>>{};
  final fall = <String>[];
  final byOver = <int>[];
  var over = <BallMark>[];
  int _overRuns = 0, _overNo = -1;

  void walkIn(String id) => bat[id] = [0, 0, 0, 0];

  void _swap() {
    final was = striker;
    striker = partner;
    partner = was;
  }

  /// Adds one delivery. Returns the batter if it took them to fifty.
  Player? play(_Ball b) {
    if (b.over != _overNo) {
      _overNo = b.over;
      _overRuns = 0;
      ballInOver = 0;
      over = [];
      byOver.add(runs);
    }
    bowler = b.bowlerId;
    final figures = bowl.putIfAbsent(b.bowlerId, () => [0, 0, 0, 0]);
    final card = bat[b.strikerId]!;
    final before = card[0];
    runs += b.total;
    pairRuns += b.total;
    figures[2] += b.total;
    _overRuns += b.total;
    if (b.legal) {
      balls++;
      ballInOver++;
      pairBalls++;
      figures[0]++;
      card[1]++;
      card[0] += b.runs;
      if (b.runs == 4) card[2]++;
      if (b.runs == 6) card[3]++;
    } else {
      extras++;
    }
    byOver.last = runs;
    over.add(
      BallMark(
        b.out != _Out.none
            ? 'W'
            : b.extra.isNotEmpty
            ? b.extra
            : b.runs == 0
            ? '•'
            : '${b.runs}',
        boundary: b.runs >= 4,
        wicket: b.out != _Out.none,
        extra: b.extra.isNotEmpty,
      ),
    );
    if (b.out != _Out.none) {
      wickets++;
      final by = fielding.player(b.bowlerId)?.surname ?? '';
      final f = fielding.player(b.fielderId)?.surname ?? '';
      dismissed[b.strikerId] = switch (b.out) {
        _Out.bowled => 'b $by',
        _Out.caught => 'c $f b $by',
        _Out.lbw => 'lbw b $by',
        _Out.stumped => 'st $f b $by',
        _ => 'run out ($f)',
      };
      if (b.out != _Out.runOut) figures[3]++;
      fall.add('$runs/$wickets (${b.over}.$ballInOver)');
      pairRuns = 0;
      pairBalls = 0;
      if (b.nextId.isNotEmpty) walkIn(b.nextId);
      striker = b.nextId;
    } else {
      striker = b.strikerId;
    }
    if (b.runs.isOdd) _swap();
    if (b.legal && ballInOver == 6) {
      if (_overRuns == 0) figures[1]++;
      _swap();
    }
    return before < 50 && card[0] >= 50 ? team.player(b.strikerId) : null;
  }

  Innings innings({required bool live}) => Innings(
    batting: batting,
    runs: runs,
    wickets: wickets,
    balls: balls,
    extras: extras,
    closed: closed,
    fallOfWickets: List.unmodifiable(fall),
    byOver: List.unmodifiable(byOver),
    batters: [
      for (final p in team.squad.take(11))
        switch (bat[p.id]) {
          null => BatterLine(player: p, state: BatterState.yetToBat),
          final c => BatterLine(
            player: p,
            state: dismissed.containsKey(p.id)
                ? BatterState.out
                : BatterState.batting,
            runs: c[0],
            balls: c[1],
            fours: c[2],
            sixes: c[3],
            dismissal: dismissed[p.id] ?? 'not out',
            onStrike: live && !closed && p.id == striker,
          ),
        },
    ],
    bowlers: [
      for (final e in bowl.entries)
        if (fielding.player(e.key) case final p?)
          BowlerLine(
            player: p,
            balls: e.value[0],
            maidens: e.value[1],
            runs: e.value[2],
            wickets: e.value[3],
            bowling: live && !closed && e.key == bowler,
          ),
    ],
  );
}
