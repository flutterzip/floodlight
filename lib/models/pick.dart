import 'package:flutter/foundation.dart';

import 'league.dart';
import 'match.dart';

enum PickChoice {
  home,
  draw,
  away;

  Side? get side => switch (this) {
    home => Side.home,
    away => Side.away,
    draw => null,
  };

  static PickChoice of(Side? side) => switch (side) {
    Side.home => home,
    Side.away => away,
    null => draw,
  };
}

/// Open until the match ends, then right or wrong. Worked out from the
/// result, never stored.
enum PickResult { open, won, lost }

/// A call on who wins a match, made before it starts.
@immutable
class Pick {
  const Pick({
    required this.id,
    required this.fixtureId,
    required this.choice,
    required this.madeAt,
  });

  final String id;
  final String fixtureId;
  final PickChoice choice;
  final DateTime madeAt;

  Pick copyWith({PickChoice? choice}) => Pick(
    id: id,
    fixtureId: fixtureId,
    choice: choice ?? this.choice,
    madeAt: madeAt,
  );

  PickResult resultFor(MatchSnapshot match) {
    if (match.stage != MatchStage.finished) return PickResult.open;
    final t = match.tally;
    final winner = t.home == t.away
        ? null
        : t.home > t.away
        ? Side.home
        : Side.away;
    return winner == choice.side ? PickResult.won : PickResult.lost;
  }

  factory Pick.fromJson(Map<String, dynamic> j) => Pick(
    id: j['id'] as String,
    fixtureId: j['fixtureId'] as String,
    choice: PickChoice.values.byName(j['choice'] as String),
    madeAt: DateTime.parse(j['madeAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'fixtureId': fixtureId,
    'choice': choice.name,
    'madeAt': madeAt.toIso8601String(),
  };
}

/// Which alerts the person wants from the teams they follow.
@immutable
class AlertPrefs {
  const AlertPrefs({
    this.starts = true,
    this.scores = true,
    this.results = true,
  });

  final bool starts;
  final bool scores;
  final bool results;

  AlertPrefs copyWith({bool? starts, bool? scores, bool? results}) =>
      AlertPrefs(
        starts: starts ?? this.starts,
        scores: scores ?? this.scores,
        results: results ?? this.results,
      );

  factory AlertPrefs.fromJson(Map<String, dynamic> j) => AlertPrefs(
    starts: j['starts'] as bool? ?? true,
    scores: j['scores'] as bool? ?? true,
    results: j['results'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'starts': starts,
    'scores': scores,
    'results': results,
  };
}

enum AlertKind { start, score, result }

/// One alert in the inbox, made from a moment in a followed team's match.
@immutable
class Alert {
  const Alert({
    required this.id,
    required this.fixtureId,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    required this.teamId,
  });

  final String id;
  final String fixtureId;
  final AlertKind kind;
  final String title;
  final String body;
  final DateTime at;

  /// The followed team it is about.
  final String teamId;
}
