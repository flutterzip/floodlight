import 'package:flutter/material.dart';

import '../config/motion.dart';
import 'alerts/alerts_screen.dart';
import 'match/match_screen.dart';
import 'search/search_screen.dart';
import 'shell/main_shell.dart';
import 'team/team_screen.dart';

// Where a tap goes, wherever it happens. Screens call these rather than
// wiring navigation themselves, so a match opens the same way from Scores,
// a table, a team, an alert or the live pill.

/// A page inside the current tab, so the glass bar stays.
Route<T> tabRoute<T>(Widget page, {String? name}) => MaterialPageRoute<T>(
  settings: RouteSettings(name: name),
  builder: (_) => page,
);

/// A page that fades up in place: for Search, which grows out of its pill.
Route<T> fadeRoute<T>(Widget page, {String? name}) => PageRouteBuilder<T>(
  settings: RouteSettings(name: name),
  transitionDuration: Motion.medium,
  reverseTransitionDuration: Motion.short,
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  ),
);

/// Opens a match in the current tab, unless that match is already on top.
void openMatch(BuildContext context, String fixtureId) {
  final nav = tabNavigator(context);
  final name = 'match:$fixtureId';
  var onTop = false;
  nav.popUntil((r) {
    onTop = r.settings.name == name;
    return true;
  });
  if (!onTop) {
    nav.push(tabRoute(MatchScreen(fixtureId: fixtureId), name: name));
  }
}

void openTeam(BuildContext context, String teamId) => tabNavigator(
  context,
).push(tabRoute(TeamScreen(teamId: teamId), name: 'team:$teamId'));

void openSearch(BuildContext context) =>
    tabNavigator(context).push(fadeRoute(const SearchScreen(), name: 'search'));

/// Opens Alerts in the current tab, unless it is already on top.
void openAlerts(BuildContext context) {
  final nav = tabNavigator(context);
  var onTop = false;
  nav.popUntil((r) {
    onTop = r.settings.name == 'alerts';
    return true;
  });
  if (!onTop) nav.push(tabRoute(const AlertsScreen(), name: 'alerts'));
}
