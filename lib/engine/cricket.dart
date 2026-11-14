import 'dart:math' as math;

import '../models/cricket.dart';
import '../models/league.dart';
import '../models/match.dart';
import 'chance.dart';
import 'match_script.dart';
import 'rng.dart';

part 'cricket_card.dart';

enum _Out { none, bowled, caught, lbw, runOut, stumped }

sealed class _Step {
  const _Step();
}

class _Toss extends _Step {
  const _Toss(this.batting);
  final Side batting;
}

class _Open extends _Step {
  const _Open(this.batting, this.strikerId, this.partnerId);
  final Side batting;
  final String strikerId;
  final String partnerId;
}

class _Close extends _Step {
  const _Close();
}

class _Ball extends _Step {
  const _Ball({
    required this.over,
    required this.bowlerId,
    required this.strikerId,
    required this.runs,
    required this.extra,
    required this.out,
    required this.text,
    this.fielderId = '',
    this.nextId = '',
  });

  final int over;
  final String bowlerId;
  final String strikerId;

  /// Off the bat.
  final int runs;

  /// '', 'wd' or 'nb'. Either costs a run and is bowled again.
  final String extra;
  final _Out out;
  final String text;
  final String fielderId;

  /// Who walks out after a wicket, if anyone is left.
  final String nextId;

  bool get legal => extra.isEmpty;
  int get total => runs + (legal ? 0 : 1);
}

/// A twenty over match, played once from the fixture's seed.
///
/// A ball takes [secondsPerBall] real seconds, so a full match lasts about
/// nine and a half minutes with the change of innings.
class CricketScript extends MatchScript<CricketSnapshot> {
  CricketScript(super.fixture, super.home, super.away) {
    _play();
  }

  static const secondsPerBall = 2.15;
  static const _betweenOvers = .9;
  static const _inningsBreak = 28.0;
  static const _par = 158.0;

  final _steps = <_Step>[];
  final _at = <Duration>[];
  final _clock = <String>[];
  double _breakStart = 0, _breakEnd = 0;
  late final double _edgeRuns;

  @override
  List<Duration> get offsets => _at;

  static const _dots = [
    'defended back down the pitch',
    'beaten outside off',
    'pushed straight to cover',
    'left alone',
    'a yorker dug out',
    'played and missed',
  ];
  static const _singles = [
    'worked off the pads for one',
    'dropped into the off side for a single',
    'pushed to long on for one',
    'a quick single to mid wicket',
  ];
  static const _twos = [
    'driven into the gap, they come back for two',
    'clipped behind square for a couple',
  ];
  static const _fours = [
    'FOUR, driven through the covers',
    'FOUR, cut hard past point',
    'FOUR, pulled in front of square',
    'FOUR, a thick edge runs away to third',
    'FOUR, flicked fine off the pads',
  ];
  static const _sixes = [
    'SIX, launched over long on',
    'SIX, picked up over deep mid wicket',
    'SIX, straight back over the bowler',
    'SIX, slog swept into the stand',
  ];

  /// One rating has to serve two jobs: a bowler does not bat as well as
  /// they bowl, and an all-rounder gives a little away at both.
  static int _batting(Player p) => switch (p.role) {
    'BWL' => p.rating - 30,
    'AR' => p.rating - 7,
    _ => p.rating,
  };

  static int _bowling(Player p) => p.role == 'AR' ? p.rating - 6 : p.rating;

  void _play() {
    final rng = Rng.of(fixture.id);
    _edgeRuns = (home.rating + 2 - away.rating) * .9;
    var t = 0.0;
    void add(_Step step, String clock) {
      _at.add(realTime(t));
      _steps.add(step);
      _clock.add(clock);
    }

    final first = rng.chance(.5) ? Side.home : Side.away;
    add(_Toss(first), '');
    int? target;
    for (final batting in [first, first.other]) {
      final bat = (batting == Side.home ? home : away).squad.take(11).toList();
      final field = (batting == Side.home ? away : home).squad
          .take(11)
          .toList();
      final attack = [
        for (final p in field)
          if (p.role == 'BWL' || p.role == 'AR') p,
      ];
      final bowled = <String, int>{};
      var striker = bat[0], partner = bat[1];
      var next = 2, runs = 0, wickets = 0, balls = 0;
      String? lastBowler;
      add(_Open(batting, striker.id, partner.id), '0.0 ov');

      innings:
      for (var over = 0; over < CricketSnapshot.oversPerSide; over++) {
        final free = [
          for (final p in attack)
            if (p.id != lastBowler && (bowled[p.id] ?? 0) < 4) p,
        ];
        final bowler = rng.weighted(
          free.isEmpty ? attack : free,
          (p) => p.role == 'BWL' ? 2.2 : 1.0,
        );
        bowled[bowler.id] = (bowled[bowler.id] ?? 0) + 1;
        lastBowler = bowler.id;
        var legal = 0;
        while (legal < 6) {
          t += secondsPerBall;
          var push = over < 6
              ? .15
              : over < 15
              ? 0.0
              : .3;
          if (target != null) {
            final left = CricketSnapshot.ballsPerSide - balls;
            final rate = (target - runs) * 6 / math.max(left, 1);
            push += ((rate - 8.2) / 10).clamp(-.2, .5);
          }
          final skill = (_batting(striker) - _bowling(bowler)) / 100;
          final pOut = (.047 * (1 - skill * 1.6 + push * .55)).clamp(.012, .12);
          final pSix = .048 * (1 + skill * 2.2 + push * 1.5);
          final pFour = .115 * (1 + skill * 1.6 + push * .9);
          final pOne = .36 * (1 - push * .25);
          final r = rng.d();
          var edge = 0.0;
          bool under(double p) => r < (edge += p);
          final who = '${bowler.surname} to ${striker.surname}';
          var off = 0, extra = '', out = _Out.none, fielder = '', text = '';
          if (under(.03)) {
            extra = 'wd';
            text = '$who, wide down the leg side';
          } else if (under(.008)) {
            extra = 'nb';
            text = '$who, no ball, overstepped';
          } else if (under(pOut)) {
            final k = rng.d();
            final others = [
              for (final p in field)
                if (p.id != bowler.id) p,
            ];
            final keeper = field.firstWhere(
              (p) => p.role == 'WK',
              orElse: () => field.first,
            );
            if (k < .58) {
              out = _Out.caught;
              fielder = rng.chance(.22) ? keeper.id : rng.pick(others).id;
              text = '$who, OUT, caught';
            } else if (k < .76) {
              out = _Out.bowled;
              text = '$who, OUT, bowled him';
            } else if (k < .88) {
              out = _Out.lbw;
              text = '$who, OUT, trapped in front';
            } else if (k < .95) {
              out = _Out.runOut;
              fielder = rng.pick(others).id;
              text = '$who, OUT, run out going for a second';
            } else {
              out = _Out.stumped;
              fielder = keeper.id;
              text = '$who, OUT, stumped';
            }
          } else if (under(pSix)) {
            off = 6;
            text = '$who, ${rng.pick(_sixes)}';
          } else if (under(pFour)) {
            off = 4;
            text = '$who, ${rng.pick(_fours)}';
          } else if (under(.07)) {
            off = 2;
            text = '$who, ${rng.pick(_twos)}';
          } else if (under(.004)) {
            off = 3;
            text = '$who, three, hauled in just short of the rope';
          } else if (under(pOne)) {
            off = 1;
            text = '$who, ${rng.pick(_singles)}';
          } else {
            text = '$who, ${rng.pick(_dots)}';
          }

          final isLegal = extra.isEmpty;
          if (isLegal) {
            legal++;
            balls++;
          }
          runs += off + (isLegal ? 0 : 1);
          var arriving = '';
          if (out != _Out.none) {
            wickets++;
            if (next < bat.length) arriving = bat[next].id;
          }
          add(
            _Ball(
              over: over,
              bowlerId: bowler.id,
              strikerId: striker.id,
              runs: off,
              extra: extra,
              out: out,
              text: text,
              fielderId: fielder,
              nextId: arriving,
            ),
            '${oversText(balls)} ov',
          );
          if (out != _Out.none) {
            if (wickets >= 10) break innings;
            striker = bat[next++];
          }
          if (off.isOdd) (striker, partner) = (partner, striker);
          if (target != null && runs >= target) break innings;
        }
        (striker, partner) = (partner, striker);
        t += _betweenOvers;
      }
      t += 1.2;
      add(const _Close(), '${oversText(balls)} ov');
      if (target == null) {
        target = runs + 1;
        _breakStart = t;
        t += _inningsBreak;
        _breakEnd = t;
      }
    }
  }

  @override
  bool pausedAt(Duration elapsed) {
    final s = elapsed.inMicroseconds / 1e6;
    return s >= _breakStart && s < _breakEnd;
  }

  @override
  String clockAt(Duration elapsed) {
    if (elapsed.isNegative) return '';
    if (elapsed >= length) return 'Result';
    if (pausedAt(elapsed)) return 'Break';
    final n = stepsBy(elapsed);
    return n == 0 ? '' : _clock[n - 1];
  }

  /// The home side's chance, given who is batting and how the innings
  /// stands.
  WinChance _chance(List<_Card> cards) {
    WinChance forBatting(Side batting, double p) => batting == Side.home
        ? WinChance(home: p, draw: 0, away: 1 - p)
        : WinChance(home: 1 - p, draw: 0, away: p);
    if (cards.isEmpty) {
      return marginChance(expected: _edgeRuns, spread: 34);
    }
    final c = cards.last;
    final edge = c.batting == Side.home ? _edgeRuns : -_edgeRuns;
    final left = CricketSnapshot.ballsPerSide - c.balls;
    final toCome = left * 1.32 * (1 - c.wickets * .075);
    if (cards.length == 1) {
      final part = left / CricketSnapshot.ballsPerSide;
      return forBatting(
        c.batting,
        marginChance(
          expected: c.runs + toCome - _par + edge * part,
          spread: 22 + 30 * part,
        ).home,
      );
    }
    final need = cards.first.runs + 1 - c.runs;
    final part = left / CricketSnapshot.ballsPerSide;
    return forBatting(
      c.batting,
      marginChance(
        expected: toCome - need + edge * part,
        spread: 6 + 26 * math.sqrt(part),
      ).home,
    );
  }

  @override
  CricketSnapshot build(int count, MatchStage stage) {
    final cards = <_Card>[];
    final feed = <FeedItem>[];
    var paused = false, boundaries = 0;

    for (var i = 0; i < count; i++) {
      switch (_steps[i]) {
        case _Toss(batting: final side):
          feed.add(
            FeedItem(
              id: 't$i',
              at: _at[i],
              clock: 'Toss',
              kind: FeedKind.period,
              title: 'Toss',
              detail: '${team(side).name} will bat first',
              major: true,
            ),
          );
        case _Open(:final batting, :final strikerId, :final partnerId):
          paused = false;
          cards.add(
            _Card(batting, team(batting), team(batting.other))
              ..walkIn(strikerId)
              ..walkIn(partnerId)
              ..striker = strikerId
              ..partner = partnerId,
          );
          if (cards.length == 2) {
            feed.add(
              FeedItem(
                id: 'o$i',
                at: _at[i],
                clock: '0.0',
                kind: FeedKind.period,
                title: 'The chase begins',
                detail:
                    '${team(batting).name} need ${cards.first.runs + 1} '
                    'from 120 balls',
                major: true,
              ),
            );
          }
        case _Close():
          final c = cards.last..closed = true;
          paused = cards.length == 1;
          feed.add(
            FeedItem(
              id: 'c$i',
              at: _at[i],
              clock: oversText(c.balls),
              kind: FeedKind.period,
              title: cards.length == 1 ? 'End of the innings' : 'Result',
              detail:
                  '${c.team.name} ${c.runs}/${c.wickets} (${oversText(c.balls)})',
              major: true,
            ),
          );
        case final _Ball b:
          final c = cards.last;
          final fifty = c.play(b);
          if (b.runs >= 4) boundaries++;
          final label = '${b.over}.${c.ballInOver}';
          feed.add(
            FeedItem(
              id: 'b$i',
              at: _at[i],
              clock: label,
              kind: b.out != _Out.none
                  ? FeedKind.wicket
                  : b.runs >= 4
                  ? FeedKind.score
                  : FeedKind.note,
              side: c.batting,
              major: b.out != _Out.none,
              badge: b.out != _Out.none
                  ? 'W'
                  : b.extra.isNotEmpty
                  ? b.extra
                  : b.runs == 0
                  ? '•'
                  : '${b.runs}',
              title: b.text,
              detail: '${c.team.short} ${c.runs}/${c.wickets}',
            ),
          );
          if (fifty != null) {
            feed.add(
              FeedItem(
                id: 'm$i',
                at: _at[i],
                clock: label,
                kind: FeedKind.score,
                side: c.batting,
                major: true,
                badge: '50',
                title: 'Fifty for ${fifty.surname}',
                detail: 'Off ${c.bat[fifty.id]![1]} balls',
              ),
            );
          }
      }
    }

    final finished = stage == MatchStage.finished;
    final innings = [for (final c in cards) c.innings(live: stage.inPlay)];
    WinChance chance;
    if (finished && innings.length == 2) {
      final a = innings.first, b = innings.last;
      final winner = b.runs == a.runs
          ? null
          : b.runs > a.runs
          ? b.batting
          : a.batting;
      chance = WinChance(
        home: winner == Side.home ? 1 : (winner == null ? .5 : 0),
        draw: 0,
        away: winner == Side.away ? 1 : (winner == null ? .5 : 0),
      );
    } else {
      chance = _chance(cards);
    }
    final last = cards.isEmpty ? null : cards.last;
    return CricketSnapshot(
      fixture: fixture,
      home: home,
      away: away,
      stage: stage,
      revision: count,
      innings: innings,
      thisOver: last == null || last.closed ? const [] : last.over,
      partnership: last == null ? (0, 0) : (last.pairRuns, last.pairBalls),
      feed: feed,
      chance: chance,
      paused: paused && !finished,
      boundaries: boundaries,
    );
  }
}
