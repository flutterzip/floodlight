import 'package:flutter/material.dart';

import '../models/league.dart';

/// The icon that stands for each sport.
IconData sportIcon(Sport sport) => switch (sport) {
  Sport.football => Icons.sports_soccer_rounded,
  Sport.basketball => Icons.sports_basketball_rounded,
  Sport.cricket => Icons.sports_cricket_rounded,
};
