import 'package:flutter/foundation.dart';

import 'league.dart';

/// One match on the calendar: who, where in the season, and when it starts.
/// How it is going is never stored. That is worked out from the clock.
@immutable
class Fixture {
  const Fixture({
    required this.id,
    required this.competitionId,
    required this.sport,
    required this.season,
    required this.round,
    required this.index,
    required this.homeId,
    required this.awayId,
    required this.kickoff,
  });

  /// `competition:absoluteRound:index`. Everything else about the fixture
  /// can be rebuilt from it, so a stored pick needs nothing but this.
  final String id;
  final String competitionId;
  final Sport sport;

  /// Both start at 1, for display.
  final int season;
  final int round;

  /// The fixture's place within its round.
  final int index;
  final String homeId;
  final String awayId;
  final DateTime kickoff;

  String teamId(Side side) => side == Side.home ? homeId : awayId;

  bool involves(String teamId) => homeId == teamId || awayId == teamId;

  Side? sideOf(String teamId) => homeId == teamId
      ? Side.home
      : awayId == teamId
      ? Side.away
      : null;

  @override
  bool operator ==(Object other) => other is Fixture && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The parts of a fixture id.
typedef FixtureRef = ({String competitionId, int absoluteRound, int index});

FixtureRef? parseFixtureId(String id) {
  final parts = id.split(':');
  if (parts.length != 3) return null;
  final round = int.tryParse(parts[1]);
  final index = int.tryParse(parts[2]);
  if (round == null || index == null) return null;
  return (competitionId: parts[0], absoluteRound: round, index: index);
}
