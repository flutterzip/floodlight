import 'dart:math' as math;

import '../models/football.dart';
import '../models/league.dart';
import '../models/match.dart';
import 'chance.dart';
import 'match_script.dart';
import 'rng.dart';

part 'football_fold.dart';

sealed class _Step {
  const _Step();
}

class _Whistle extends _Step {
  const _Whistle(this.period);
  final FootballPeriod period;
}

/// A minute has been played: its share of the ball and its passes count.
class _Minute extends _Step {
  const _Minute(this.slot);
  final int slot;
}

class _Happened extends _Step {
  const _Happened(this.event);
  final FootballEvent event;
}

/// Ninety minutes and stoppage, played once from the fixture's seed.
///
/// A minute of football takes [secondsPerMinute] real seconds, so a match
/// lasts about eight and a half minutes with the break.
class FootballScript extends MatchScript<FootballSnapshot> {
  FootballScript(super.fixture, super.home, super.away) {
    _play();
  }

  static const secondsPerMinute = 5.0;
  static const halfTimeSeconds = 40.0;

  /// Goals a side scores in an even match, on average.
  static const _goalsPerSide = 1.38;

  late final int _firstHalf, _secondHalf;
  final _steps = <_Step>[];
  final _at = <Duration>[];
  final _share = <double>[];
  final _momentum = <double>[];
  final _passes = <(int, int, int, int)>[];
  late final double _edge;

  @override
  List<Duration> get offsets => _at;

  int get _slots => _firstHalf + _secondHalf;
  double get _breakStart => _firstHalf * secondsPerMinute;
  double get _secondStart => _breakStart + halfTimeSeconds;

  double _slotStart(int slot) => slot < _firstHalf
      ? slot * secondsPerMinute
      : _secondStart + (slot - _firstHalf) * secondsPerMinute;

  (int minute, int added) _label(int slot) {
    if (slot < _firstHalf) {
      final m = slot + 1;
      return m > 45 ? (45, m - 45) : (m, 0);
    }
    final m = 46 + slot - _firstHalf;
    return m > 90 ? (90, m - 90) : (m, 0);
  }

  void _play() {
    final rng = Rng.of(fixture.id);
    // Three points of rating for playing at home.
    _edge = (home.rating + 3 - away.rating) / 100;
    _firstHalf = 45 + 1 + rng.i(3);
    _secondHalf = 45 + 2 + rng.i(5);

    final onPitch = {
      Side.home: home.squad.take(11).toList(),
      Side.away: away.squad.take(11).toList(),
    };
    final bench = {
      Side.home: home.squad.skip(11).toList(),
      Side.away: away.squad.skip(11).toList(),
    };
    final booked = <String>{};
    final reds = {Side.home: 0, Side.away: 0};
    // When each side makes its changes.
    final changes = {
      for (final s in Side.values)
        s: [for (var i = 0; i < 3 + rng.i(3); i++) _firstHalf + 9 + rng.i(34)],
    };

    final timed = <(double, _Step)>[
      (0, const _Whistle(FootballPeriod.firstHalf)),
    ];
    void add(int slot, double within, FootballEvent e) =>
        timed.add((_slotStart(slot) + within * secondsPerMinute, _Happened(e)));

    double roleWeight(Player p, {required bool scoring}) {
      final w = switch (p.role) {
        'FW' => scoring ? 5.0 : 1.0,
        'MF' => scoring ? 2.4 : 2.5,
        'DF' => scoring ? .8 : 3.0,
        _ => .02,
      };
      return w * (scoring ? p.rating / 75 : 1);
    }

    var possession = .5 + _edge * .35;
    for (var slot = 0; slot < _slots; slot++) {
      if (slot == _firstHalf) {
        timed
          ..add((_breakStart, const _Whistle(FootballPeriod.halfTime)))
          ..add((_secondStart, const _Whistle(FootballPeriod.secondHalf)));
      }
      final (minute, added) = _label(slot);
      final lean = _edge * .35 + (reds[Side.away]! - reds[Side.home]!) * .06;
      // The ball drifts towards whoever has had it, and back to the mean.
      possession += (rng.d() - .5) * .1 + (.5 + lean - possession) * .12;
      possession = possession.clamp(.24, .76);
      var pressure = (possession - .5) * 2.2 + (rng.d() - .5) * .5;

      if (rng.chance(.27)) {
        final side = rng.chance(possession) ? Side.home : Side.away;
        final sign = side == Side.home ? 1 : -1;
        final shooter = rng.weighted(
          onPitch[side]!,
          (p) => roleWeight(p, scoring: true),
        );
        final xg = .04 + math.pow(rng.d(), 2.2) * .5;
        final roll = rng.d();
        final finish =
            xg * .56 * (1 + sign * _edge * 1.1) * (shooter.rating / 76);
        final within = .15 + rng.d() * .6;
        FootballEvent shot(FootballEventKind kind, {String other = ''}) =>
            FootballEvent(
              kind: kind,
              side: side,
              minute: minute,
              added: added,
              playerId: shooter.id,
              otherId: other,
              xg: xg,
            );
        if (roll < finish) {
          final mates = [
            for (final p in onPitch[side]!)
              if (p.id != shooter.id && p.role != 'GK') p,
          ];
          final assist = rng.chance(.72) && mates.isNotEmpty
              ? rng.weighted(mates, (p) => p.role == 'MF' ? 2.0 : 1.0).id
              : '';
          add(slot, within, shot(FootballEventKind.goal, other: assist));
        } else if (roll < finish + .3) {
          add(slot, within, shot(FootballEventKind.saved));
        } else if (roll < finish + .58) {
          add(slot, within, shot(FootballEventKind.offTarget));
        } else {
          add(slot, within, shot(FootballEventKind.blocked));
        }
        if (roll >= finish && rng.chance(.34)) {
          add(
            slot,
            math.min(within + .2, .95),
            FootballEvent(
              kind: FootballEventKind.corner,
              side: side,
              minute: minute,
              added: added,
            ),
          );
        }
        pressure += sign * (.45 + xg * 1.4);
      }

      if (rng.chance(.21)) {
        // The side without the ball fouls more.
        final side = rng.chance(1 - possession) ? Side.home : Side.away;
        final player = rng.weighted(
          onPitch[side]!,
          (p) => roleWeight(p, scoring: false),
        );
        final within = rng.d() * .9;
        FootballEvent foul(FootballEventKind kind) => FootballEvent(
          kind: kind,
          side: side,
          minute: minute,
          added: added,
          playerId: player.id,
        );
        add(slot, within, foul(FootballEventKind.foul));
        final card = rng.d();
        final second = booked.contains(player.id);
        if (card < .006 || (card < .16 && second)) {
          add(slot, within + .05, foul(FootballEventKind.red));
          onPitch[side]!.remove(player);
          reds[side] = reds[side]! + 1;
        } else if (card < .16) {
          add(slot, within + .05, foul(FootballEventKind.yellow));
          booked.add(player.id);
        }
      }

      if (rng.chance(.045)) {
        final side = rng.chance(possession) ? Side.home : Side.away;
        add(
          slot,
          rng.d() * .9,
          FootballEvent(
            kind: FootballEventKind.offside,
            side: side,
            minute: minute,
            added: added,
          ),
        );
      }

      for (final side in Side.values) {
        for (final _ in changes[side]!.where((s) => s == slot)) {
          final off = [
            for (final p in onPitch[side]!)
              if (p.role != 'GK' &&
                  home.squad.indexOf(p) < 11 &&
                  away.squad.indexOf(p) < 11)
                p,
          ];
          if (bench[side]!.isEmpty || off.isEmpty) continue;
          final leaving = rng.pick(off);
          // Like for like where the bench allows it.
          final arriving = bench[side]!.firstWhere(
            (p) => p.role == leaving.role,
            orElse: () => bench[side]!.firstWhere(
              (p) => p.role != 'GK',
              orElse: () => bench[side]!.first,
            ),
          );
          bench[side]!.remove(arriving);
          onPitch[side]![onPitch[side]!.indexOf(leaving)] = arriving;
          add(
            slot,
            .02,
            FootballEvent(
              kind: FootballEventKind.substitution,
              side: side,
              minute: minute,
              added: added,
              playerId: arriving.id,
              otherId: leaving.id,
            ),
          );
        }
      }

      _share.add(possession);
      _momentum.add(pressure.clamp(-1.6, 1.6) / 1.6);
      final hp = (possession * 11 + rng.d() * 2).round();
      final ap = ((1 - possession) * 11 + rng.d() * 2).round();
      _passes.add((
        hp,
        (hp * (.76 + _edge * .12 + rng.d() * .1)).round(),
        ap,
        (ap * (.76 - _edge * .12 + rng.d() * .1)).round(),
      ));
      timed.add((_slotStart(slot) + secondsPerMinute, _Minute(slot)));
    }
    timed.add((
      _slotStart(_slots - 1) + secondsPerMinute,
      const _Whistle(FootballPeriod.fullTime),
    ));

    // A stable sort, so a minute's events stay in the order they were made.
    final order = List.generate(timed.length, (i) => i)
      ..sort((a, b) {
        final c = timed[a].$1.compareTo(timed[b].$1);
        return c != 0 ? c : a.compareTo(b);
      });
    for (final i in order) {
      _at.add(realTime(timed[i].$1));
      _steps.add(timed[i].$2);
    }
  }

  @override
  bool pausedAt(Duration elapsed) {
    final s = elapsed.inMicroseconds / 1e6;
    return s >= _breakStart && s < _secondStart;
  }

  @override
  String clockAt(Duration elapsed) {
    final s = elapsed.inMicroseconds / 1e6;
    if (s < 0) return '';
    if (elapsed >= length) return 'FT';
    if (s >= _breakStart && s < _secondStart) return 'HT';
    final slot = s < _breakStart
        ? (s / secondsPerMinute).floor()
        : _firstHalf + ((s - _secondStart) / secondsPerMinute).floor();
    final (minute, added) = _label(slot.clamp(0, _slots - 1));
    return added > 0 ? "$minute+$added'" : "$minute'";
  }

  @override
  FootballSnapshot build(int count, MatchStage stage) =>
      _fold(this, count, stage);
}
