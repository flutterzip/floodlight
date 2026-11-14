import 'package:floodlight/models/league.dart';
import 'package:floodlight/providers/account_providers.dart';
import 'package:floodlight/providers/core_providers.dart';
import 'package:floodlight/providers/score_providers.dart';
import 'package:floodlight/screens/alerts/alerts_screen.dart';
import 'package:floodlight/screens/following/following_tab.dart';
import 'package:floodlight/screens/match/match_screen.dart';
import 'package:floodlight/screens/search/search_screen.dart';
import 'package:floodlight/screens/tables/tables_tab.dart';
import 'package:floodlight/screens/team/team_screen.dart';
import 'package:floodlight/services/store.dart';
import 'package:floodlight/widgets/follow.dart';
import 'package:floodlight/widgets/match_row.dart';
import 'package:floodlight/widgets/rolling_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const tall = Size(390, 3200);

/// A rolling number showing [text]. It paints its own glyphs, so there is
/// no Text widget to find.
Finder rolling(String text) =>
    find.byWidgetPredicate((w) => w is RollingNumber && w.text == text);

void main() {
  final seed = readSeed();
  setUp(quietMotion);

  group('following', () {
    testWidgets('each followed team comes with its match', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const FollowingTab());
      for (final id in seed.following) {
        expect(find.byKey(Key('followed-$id')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(Key('followed-$id')),
            matching: find.byType(MatchRow),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Top of the tables'), findsOneWidget);
    });

    testWidgets('unfollowing can be undone, back in the same place', (t) async {
      phone(t, size: tall);
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const FollowingTab());
      final second = seed.following[1];
      await t.tap(find.byKey(Key('unfollow-$second')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      expect(c.read(followingProvider).value, isNot(contains(second)));
      expect(store.strings(Store.following), isNot(contains(second)));
      expect(find.byKey(Key('followed-$second')), findsNothing);
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(c.read(followingProvider).value, seed.following);
    });

    testWidgets('a suggestion can be followed from the list', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const FollowingTab());
      final before = c.read(followingProvider).value!.length;
      await t.tap(find.byType(FollowButton).first);
      await t.pumpAndSettle();
      expect(c.read(followingProvider).value!.length, before + 1);
    });

    testWidgets('with nobody followed it says what following does', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(
        seed,
        signedIn: seed.profile,
        prefs: {Store.following: <String>[]},
      );
      await pumpScreen(t, c, const FollowingTab());
      expect(find.byKey(const Key('no-teams')), findsOneWidget);
      expect(find.text('Nobody followed yet'), findsOneWidget);
      // And nothing reaches the live pill or the inbox.
      expect(c.read(alertsProvider).items, isEmpty);
    });
  });

  group('picks', () {
    Future<void> open(WidgetTester t) async {
      await t.tap(find.byKey(const Key('following-Picks')));
      await t.pumpAndSettle();
    }

    testWidgets('the record is added up from the picks', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const FollowingTab());
      await open(t);
      final record = c.read(pickRecordProvider);
      expect((record.won, record.lost, record.open), (3, 1, 2));
      expect(find.byKey(const Key('pick-record')), findsOneWidget);
      expect(rolling('75%'), findsOneWidget);
      expect(find.text('Right'), findsWidgets);
      expect(find.text('Wrong'), findsWidgets);
    });

    testWidgets('removing one changes the record at once, and can be undone', (
      t,
    ) async {
      phone(t, size: tall);
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const FollowingTab());
      await open(t);
      final picks = c.read(picksProvider).value!;
      final scores = c.read(scoresProvider)!;
      final lost = picks.firstWhere(
        (p) => p.resultFor(scores.match(p.fixtureId, testNow)!).name == 'lost',
      );
      final at = picks.indexOf(lost);
      await t.tap(find.byKey(Key('remove-pick-${lost.fixtureId}')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      expect(c.read(pickRecordProvider).lost, 0);
      expect(c.read(picksProvider).value!.length, picks.length - 1);
      expect(store.string(Store.picks), isNot(contains(lost.fixtureId)));
      await t.tap(find.text('Undo'));
      await t.pumpAndSettle();
      expect(
        c.read(picksProvider).value!.indexWhere((p) => p.id == lost.id),
        at,
      );
      expect(c.read(pickRecordProvider).lost, 1);
    });

    testWidgets('with none it says how to make one', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(
        seed,
        signedIn: seed.profile,
        prefs: {Store.picks: '[]'},
      );
      await pumpScreen(t, c, const FollowingTab());
      await open(t);
      expect(find.byKey(const Key('no-picks')), findsOneWidget);
      expect(rolling('-'), findsOneWidget);
    });
  });

  group('tables', () {
    testWidgets('every team is in its table, in order, and they switch', (
      t,
    ) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TablesTab());
      final first = c.read(competitionsProvider).first;
      expect(find.byKey(Key('league-table-${first.id}')), findsOneWidget);
      final rows = c.read(tableProvider(first.id));
      for (final r in rows) {
        expect(find.byKey(Key('table-row-${r.team.id}')), findsOneWidget);
      }
      final ys = [
        for (final r in rows)
          t.getTopLeft(find.byKey(Key('table-row-${r.team.id}'))).dy,
      ];
      expect(ys, [...ys]..sort());
      expect(find.text('GD'), findsOneWidget);

      await tapVisible(t, find.byKey(const Key('table-t20')));
      expect(find.byKey(const Key('league-table-t20')), findsOneWidget);
      expect(find.text('NRR'), findsOneWidget);
      expect(find.text('GD'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('a row opens its team, which can be followed', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const TablesTab());
      final team = c
          .read(tableProvider(c.read(competitionsProvider).first.id))
          .map((r) => r.team)
          .firstWhere((team) => !seed.following.contains(team.id));
      await tapVisible(t, find.byKey(Key('table-row-${team.id}')));
      expect(find.byType(TeamScreen), findsOneWidget);
      expect(find.byKey(const Key('team-standing')), findsOneWidget);
      expect(find.byKey(const Key('team-squad')), findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      await t.tap(find.byKey(Key('follow-${team.id}')));
      await t.pumpAndSettle();
      expect(c.read(followingProvider).value!.first, team.id);
      expect(find.text('Following'), findsOneWidget);
      // A season of fourteen matches, each a way into its match.
      final season = c.read(teamSeasonProvider(team.id));
      expect(season.length, 14);
      await tapVisible(t, find.byKey(Key('season-${season.first.id}')));
      expect(find.byType(MatchScreen), findsOneWidget);
    });
  });

  group('alerts', () {
    testWidgets('opening one reads it and goes to its match', (t) async {
      phone(t, size: tall);
      // First opened a while ago, so there is a backlog to read.
      final (c, store) = await makeContainer(
        seed,
        signedIn: seed.profile,
        firstLaunch: testNow.subtract(const Duration(minutes: 15)),
      );
      await pumpScreen(t, c, const AlertsScreen());
      final alerts = c.read(alertsProvider).items;
      expect(alerts, isNotEmpty);
      // Newest first, all from followed teams.
      for (var i = 1; i < alerts.length; i++) {
        expect(alerts[i - 1].at.isBefore(alerts[i].at), isFalse);
      }
      expect(alerts.every((a) => seed.following.contains(a.teamId)), isTrue);
      final unread = c.read(unreadAlertsProvider);
      expect(unread, inInclusiveRange(1, alerts.length));
      final first = alerts.first;
      expect(find.byKey(Key('unread-${first.id}')), findsOneWidget);
      await t.tap(find.byKey(Key('alert-${first.id}')));
      await t.pumpAndSettle();
      expect(find.byType(MatchScreen), findsOneWidget);
      expect(c.read(unreadAlertsProvider), unread - 1);
      expect(store.strings(Store.alertsRead), contains(first.id));
    });

    testWidgets('mark all read, and swipe one away for good', (t) async {
      phone(t, size: tall);
      final (c, store) = await makeContainer(
        seed,
        signedIn: seed.profile,
        firstLaunch: testNow.subtract(const Duration(minutes: 15)),
      );
      await pumpScreen(t, c, const AlertsScreen());
      await t.tap(find.byKey(const Key('alerts-read-all')));
      await t.pumpAndSettle();
      expect(c.read(unreadAlertsProvider), 0);
      expect(find.byKey(const Key('alerts-read-all')), findsNothing);
      final alerts = c.read(alertsProvider).items;
      final gone = alerts.first;
      await t.drag(find.byKey(Key('alert-${gone.id}')), const Offset(-380, 0));
      await t.pumpAndSettle();
      expect(c.read(alertsProvider).items.length, alerts.length - 1);
      expect(store.strings(Store.alertsCleared), contains(gone.id));
    });

    testWidgets('a new install does not open on a backlog', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await warm(c);
      expect(
        c.read(unreadAlertsProvider),
        lessThan(c.read(alertsProvider).items.length),
      );
    });

    testWidgets('with no alerts it says when there will be some', (t) async {
      phone(t);
      final (c, _) = await makeContainer(
        seed,
        signedIn: seed.profile,
        prefs: {Store.following: <String>[]},
      );
      await pumpScreen(t, c, const AlertsScreen());
      expect(find.byKey(const Key('no-alerts')), findsOneWidget);
    });
  });

  group('search', () {
    test('every word has to match, and a name that starts with it leads', () {
      final scores = league(seed);
      List<String> names(String q) => [
        for (final h in search(
          q,
          teams: scores.teams.values,
          competitions: scores.competitions,
        ))
          switch (h) {
            TeamHit(:final team) => team.name,
            CompetitionHit(:final competition) => competition.name,
            PlayerHit(:final player) => player.name,
          },
      ];
      expect(names('north').first, 'Northgate Athletic');
      expect(names('lagos tide'), ['Lagos Tide']);
      expect(names('tide lagos'), ['Lagos Tide']);
      expect(names('cricket'), contains('Super Twenty Series'));
      expect(names('zzzz'), isEmpty);
      expect(names('   '), isEmpty);
      // A player finds their team's page.
      final player = scores.teams['nga']!.squad.first;
      expect(names(player.name), contains(player.name));
    });

    testWidgets('results as you type, a named empty state, and recents', (
      t,
    ) async {
      phone(t, size: tall);
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SearchScreen());
      for (final term in seed.recentSearches) {
        expect(find.byKey(Key('recent-$term')), findsOneWidget);
      }
      expect(find.text('Competitions'), findsOneWidget);

      await t.enterText(find.byKey(const Key('search-field')), 'qqqq');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('no-results')), findsOneWidget);
      expect(find.text('Nothing for "qqqq"'), findsOneWidget);

      await t.enterText(find.byKey(const Key('search-field')), 'harbour');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('hit-team-hbc')), findsOneWidget);
      await t.tap(find.byKey(const Key('hit-team-hbc')));
      await t.pumpAndSettle();
      expect(find.byType(TeamScreen), findsOneWidget);
      expect(store.strings(Store.recentSearches)!.first, 'harbour');
      expect(
        c.read(recentSearchesProvider).value!.length,
        lessThanOrEqualTo(6),
      );
    });

    testWidgets('recent searches can be removed one by one or cleared', (
      t,
    ) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpScreen(t, c, const SearchScreen());
      final first = seed.recentSearches.first;
      await t.tap(find.byTooltip('Remove $first'));
      await t.pumpAndSettle();
      expect(c.read(recentSearchesProvider).value, isNot(contains(first)));
      await t.tap(find.text('Clear'));
      await t.pumpAndSettle();
      expect(c.read(recentSearchesProvider).value, isEmpty);
      expect(find.text('Recent'), findsNothing);
      expect(
        c.read(competitionsProvider).any((x) => x.sport == Sport.cricket),
        isTrue,
      );
    });
  });
}
