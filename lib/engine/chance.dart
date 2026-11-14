import 'dart:math' as math;

import '../models/match.dart';

/// The chance of each result in a low-scoring game, from the goals each
/// side is still expected to score. Sums two Poisson distributions.
WinChance poissonChance({
  required int lead,
  required double homeToCome,
  required double awayToCome,
}) {
  const most = 8;
  List<double> pmf(double mean) {
    final out = List<double>.filled(most + 1, 0);
    var p = math.exp(-mean);
    for (var k = 0; k <= most; k++) {
      out[k] = p;
      p = p * mean / (k + 1);
    }
    return out;
  }

  final h = pmf(math.max(homeToCome, 0)), a = pmf(math.max(awayToCome, 0));
  var home = 0.0, draw = 0.0, away = 0.0;
  for (var i = 0; i <= most; i++) {
    for (var j = 0; j <= most; j++) {
      final p = h[i] * a[j];
      final margin = lead + i - j;
      if (margin > 0) {
        home += p;
      } else if (margin == 0) {
        draw += p;
      } else {
        away += p;
      }
    }
  }
  final sum = home + draw + away;
  return WinChance(home: home / sum, draw: draw / sum, away: away / sum);
}

/// The chance the home side wins when the final margin is roughly normal:
/// [expected] is where the margin is heading and [spread] how far it could
/// still swing.
WinChance marginChance({required double expected, required double spread}) {
  final z = expected / math.max(spread, .01);
  // A logistic curve close to the normal distribution's.
  final p = 1 / (1 + math.exp(-1.702 * z));
  return WinChance(home: p, draw: 0, away: 1 - p);
}
