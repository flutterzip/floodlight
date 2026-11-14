import 'package:flutter/foundation.dart';

/// The sports the app covers. Adding one means a new [Sport], an engine in
/// `lib/engine/` and its scorecard sections; nothing else is sport-aware.
enum Sport {
  football('Football'),
  basketball('Basketball'),
  cricket('Cricket');

  const Sport(this.label);
  final String label;
}

enum Side {
  home,
  away;

  Side get other => this == home ? away : home;
}

/// How a crest is drawn. The pattern and a tint index are all a team's seed
/// row holds: the colour itself comes from the palette.
enum CrestPattern {
  plain,
  stripes,
  hoops,
  sash,
  halves,
  chevron,
  quarters,
  band,
}

@immutable
class Crest {
  const Crest({required this.pattern, required this.tint});

  final CrestPattern pattern;

  /// An index into `Palette.teamTints`.
  final int tint;

  factory Crest.fromJson(Map<String, dynamic> j) => Crest(
    pattern:
        CrestPattern.values.asNameMap()[j['pattern']] ?? CrestPattern.plain,
    tint: j['tint'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {'pattern': pattern.name, 'tint': tint};
}

@immutable
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.number,
    required this.role,
    required this.rating,
  });

  final String id;
  final String name;
  final int number;

  /// GK, DF, MF or FW in football; G, F or C in basketball; BAT, WK, AR or
  /// BWL in cricket.
  final String role;

  /// 50 to 95. The engines read it; nothing on screen shows it.
  final int rating;

  /// "A. Okafor": the form a tight table has room for.
  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return name;
    return '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
  }

  String get surname => name.trim().split(RegExp(r'\s+')).last;

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    id: j['id'] as String,
    name: j['name'] as String,
    number: j['number'] as int,
    role: j['role'] as String,
    rating: j['rating'] as int? ?? 70,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'number': number,
    'role': role,
    'rating': rating,
  };
}

@immutable
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.short,
    required this.city,
    required this.sport,
    required this.crest,
    required this.rating,
    required this.squad,
    this.formation = '4-3-3',
    this.ground = '',
  });

  final String id;
  final String name;

  /// Three capitals, for a scoreboard: "NGA".
  final String short;
  final String city;
  final Sport sport;
  final Crest crest;

  /// 60 to 90. How strong the side is overall.
  final int rating;

  /// Starters first, in the order they line up or bat, then the bench.
  final List<Player> squad;

  /// Football only: defenders-midfielders-forwards.
  final String formation;
  final String ground;

  Player? player(String id) {
    for (final p in squad) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory Team.fromJson(Map<String, dynamic> j) => Team(
    id: j['id'] as String,
    name: j['name'] as String,
    short: j['short'] as String,
    city: j['city'] as String? ?? '',
    sport: Sport.values.byName(j['sport'] as String),
    crest: Crest.fromJson(j['crest'] as Map<String, dynamic>),
    rating: j['rating'] as int? ?? 75,
    squad: [
      for (final p in j['squad'] as List)
        Player.fromJson(p as Map<String, dynamic>),
    ],
    formation: j['formation'] as String? ?? '4-3-3',
    ground: j['ground'] as String? ?? '',
  );
}

@immutable
class Competition {
  const Competition({
    required this.id,
    required this.name,
    required this.short,
    required this.sport,
    required this.region,
    required this.teamIds,
  });

  final String id;
  final String name;
  final String short;
  final Sport sport;
  final String region;

  /// An even number of teams, in draw order.
  final List<String> teamIds;

  factory Competition.fromJson(Map<String, dynamic> j) => Competition(
    id: j['id'] as String,
    name: j['name'] as String,
    short: j['short'] as String? ?? j['name'] as String,
    sport: Sport.values.byName(j['sport'] as String),
    region: j['region'] as String? ?? '',
    teamIds: (j['teams'] as List).cast<String>(),
  );
}
