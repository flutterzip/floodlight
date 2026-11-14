part of 'football.dart';

List<LineupSpot> _lineup(
  Team team,
  Map<String, int> goals,
  Set<String> yellow,
  Set<String> red,
  Map<String, Player> replaced,
) {
  final rows = [
    1,
    ...team.formation.split('-').map((s) => int.tryParse(s) ?? 0),
  ];
  final starters = team.squad.take(11).toList();
  final spots = <LineupSpot>[];
  var i = 0;
  for (var r = 0; r < rows.length && i < starters.length; r++) {
    final y = r == 0
        ? .07
        : .2 + (r - 1) * (.66 / math.max(rows.length - 2, 1));
    for (var c = 0; c < rows[r] && i < starters.length; c++, i++) {
      final p = starters[i];
      spots.add(
        LineupSpot(
          player: p,
          x: (c + 1) / (rows[r] + 1),
          y: y,
          goals: goals[p.id] ?? 0,
          yellow: yellow.contains(p.id),
          red: red.contains(p.id),
          replacedBy: replaced[p.id],
        ),
      );
    }
  }
  return spots;
}

/// The match after its first [count] steps: every counter is added up from
/// the events, so the score, the statistics and the line-up marks can never
/// disagree.
FootballSnapshot _fold(FootballScript s, int count, MatchStage stage) {
  final fixture = s.fixture, home = s.home, away = s.away;
  final steps = s._steps, at = s._at, share = s._share;
  final passes = s._passes, momentum = s._momentum;
  final slots = s._slots, edge = s._edge;
  Team team(Side side) => s.team(side);

  var period = FootballPeriod.preMatch;
  var minutes = 0;
  final goals = {Side.home: 0, Side.away: 0};
  final tally = {
    for (final k in FootballEventKind.values) k: {Side.home: 0, Side.away: 0},
  };
  final xg = {Side.home: 0.0, Side.away: 0.0};
  var shareSum = 0.0;
  var hp = 0, hpOk = 0, ap = 0, apOk = 0;
  final events = <FootballEvent>[];
  final feed = <FeedItem>[];
  final scored = <String, int>{};
  final yellow = <String>{}, red = <String>{};
  final replaced = <String, Player>{};
  String name(Side side, String id) => team(side).player(id)?.surname ?? '';
  String line() => '${goals[Side.home]}-${goals[Side.away]}';

  for (var i = 0; i < count; i++) {
    switch (steps[i]) {
      case _Whistle(period: final p):
        period = p;
        final (title, detail) = switch (p) {
          FootballPeriod.firstHalf => ('Kick-off', home.ground),
          FootballPeriod.halfTime => ('Half time', line()),
          FootballPeriod.secondHalf => ('Second half', 'Back under way'),
          FootballPeriod.fullTime => ('Full time', line()),
          FootballPeriod.preMatch => ('', ''),
        };
        feed.add(
          FeedItem(
            id: 'w$i',
            at: at[i],
            clock: switch (p) {
              FootballPeriod.firstHalf => "1'",
              FootballPeriod.halfTime => 'HT',
              FootballPeriod.secondHalf => "46'",
              _ => 'FT',
            },
            kind: FeedKind.period,
            title: title,
            detail: detail,
            major: p != FootballPeriod.secondHalf,
          ),
        );
      case _Minute(slot: final slot):
        minutes = slot + 1;
        shareSum += share[slot];
        final (a, b, c, d) = passes[slot];
        hp += a;
        hpOk += b;
        ap += c;
        apOk += d;
      case _Happened(event: final e):
        events.add(e);
        tally[e.kind]![e.side] = tally[e.kind]![e.side]! + 1;
        switch (e.kind) {
          case FootballEventKind.goal:
            goals[e.side] = goals[e.side]! + 1;
            xg[e.side] = xg[e.side]! + e.xg;
            scored[e.playerId] = (scored[e.playerId] ?? 0) + 1;
            feed.add(
              FeedItem(
                id: 'e$i',
                at: at[i],
                clock: e.clock,
                kind: FeedKind.score,
                side: e.side,
                major: true,
                title: 'Goal. ${team(e.side).name} ${line()}',
                detail: e.otherId.isEmpty
                    ? name(e.side, e.playerId)
                    : '${name(e.side, e.playerId)}, set up by '
                          '${name(e.side, e.otherId)}',
              ),
            );
          case FootballEventKind.saved ||
              FootballEventKind.offTarget ||
              FootballEventKind.blocked:
            xg[e.side] = xg[e.side]! + e.xg;
            if (e.xg > .3) {
              feed.add(
                FeedItem(
                  id: 'e$i',
                  at: at[i],
                  clock: e.clock,
                  kind: FeedKind.note,
                  side: e.side,
                  title: 'Big chance',
                  detail: switch (e.kind) {
                    FootballEventKind.saved =>
                      '${name(e.side, e.playerId)} is denied by the keeper',
                    FootballEventKind.blocked =>
                      "${name(e.side, e.playerId)}'s shot is blocked",
                    _ => '${name(e.side, e.playerId)} puts it wide',
                  },
                ),
              );
            }
          case FootballEventKind.yellow:
            yellow.add(e.playerId);
            feed.add(
              FeedItem(
                id: 'e$i',
                at: at[i],
                clock: e.clock,
                kind: FeedKind.card,
                side: e.side,
                title: 'Yellow card',
                detail: name(e.side, e.playerId),
                badge: 'Y',
              ),
            );
          case FootballEventKind.red:
            red.add(e.playerId);
            feed.add(
              FeedItem(
                id: 'e$i',
                at: at[i],
                clock: e.clock,
                kind: FeedKind.card,
                side: e.side,
                major: true,
                title: 'Red card',
                detail:
                    '${name(e.side, e.playerId)} is off. '
                    '${team(e.side).name} are down to ten',
                badge: 'R',
              ),
            );
          case FootballEventKind.substitution:
            final on = team(e.side).player(e.playerId);
            if (on != null) replaced[e.otherId] = on;
            feed.add(
              FeedItem(
                id: 'e$i',
                at: at[i],
                clock: e.clock,
                kind: FeedKind.change,
                side: e.side,
                title: 'Substitution',
                detail:
                    '${name(e.side, e.playerId)} on for '
                    '${name(e.side, e.otherId)}',
              ),
            );
          case FootballEventKind.corner ||
              FootballEventKind.foul ||
              FootballEventKind.offside:
            break;
        }
    }
  }

  int n(FootballEventKind k, Side s) => tally[k]![s]!;
  int shots(Side s) =>
      n(FootballEventKind.goal, s) +
      n(FootballEventKind.saved, s) +
      n(FootballEventKind.offTarget, s) +
      n(FootballEventKind.blocked, s);
  int onTarget(Side s) =>
      n(FootballEventKind.goal, s) + n(FootballEventKind.saved, s);
  final held = minutes == 0 ? .5 : shareSum / minutes;
  double pct(int ok, int all) => all == 0 ? 0 : 100 * ok / all;
  StatPair total(String label, int Function(Side) of) =>
      StatPair(label, of(Side.home) + .0, of(Side.away) + .0);

  final left = slots - minutes;
  final rate = FootballScript._goalsPerSide / 90 * left;
  final lead = goals[Side.home]! - goals[Side.away]!;
  final redsHome = n(FootballEventKind.red, Side.home);
  final redsAway = n(FootballEventKind.red, Side.away);
  final chance = stage == MatchStage.finished
      ? WinChance(
          home: lead > 0 ? 1 : 0,
          draw: lead == 0 ? 1 : 0,
          away: lead < 0 ? 1 : 0,
        )
      : poissonChance(
          lead: lead,
          homeToCome:
              rate * (1 + edge * 1.6) * (1 - .2 * redsHome + .12 * redsAway),
          awayToCome:
              rate * (1 - edge * 1.6) * (1 - .2 * redsAway + .12 * redsHome),
        );

  return FootballSnapshot(
    fixture: fixture,
    home: home,
    away: away,
    stage: stage,
    revision: count,
    period: period,
    homeGoals: goals[Side.home]!,
    awayGoals: goals[Side.away]!,
    minute: minutes,
    events: events,
    feed: feed,
    momentum: momentum.sublist(0, minutes),
    totalMinutes: slots,
    homeLineup: _lineup(home, scored, yellow, red, replaced),
    awayLineup: _lineup(away, scored, yellow, red, replaced),
    homeBench: home.squad.skip(11).toList(),
    awayBench: away.squad.skip(11).toList(),
    chance: chance,
    stats: [
      StatPair('Possession', held * 100, (1 - held) * 100, suffix: '%'),
      total('Shots', shots),
      total('On target', onTarget),
      StatPair('Expected goals', xg[Side.home]!, xg[Side.away]!, places: 2),
      total('Corners', (s) => n(FootballEventKind.corner, s)),
      total('Fouls', (s) => n(FootballEventKind.foul, s)),
      total('Offsides', (s) => n(FootballEventKind.offside, s)),
      total('Yellow cards', (s) => n(FootballEventKind.yellow, s)),
      total('Red cards', (s) => n(FootballEventKind.red, s)),
      total('Passes', (s) => s == Side.home ? hp : ap),
      StatPair('Pass accuracy', pct(hpOk, hp), pct(apOk, ap), suffix: '%'),
    ],
  );
}
