import 'package:floodlight/models/league.dart';
import 'package:floodlight/providers/core_providers.dart';
import 'package:floodlight/providers/score_providers.dart';
import 'package:floodlight/screens/match/match_screen.dart';
import 'package:floodlight/screens/scores/scores_tab.dart';
import 'package:floodlight/screens/search/search_screen.dart';
import 'package:floodlight/screens/team/team_screen.dart';
import 'package:floodlight/services/store.dart';
import 'package:floodlight/widgets/live_card.dart';
import 'package:floodlight/widgets/match_row.dart';
import 'package:floodlight/widgets/rolling_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

// Tall enough that every section is built.
const tall = Size(390, 3600);

void main() {
  final seed = readSeed();
  setUp(quietMotion);

  testWidgets('greets the person and lays the sections out in order', (
    t,
  ) async {
    phone(t, size: tall);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ScoresTab());
    expect(find.text('Welcome, Olympicson'), findsOneWidget);
    final live = c.read(boardProvider).live.length;
    expect(live, greaterThan(0));
    expect(
      t.widget<RollingNumber>(find.byKey(const Key('live-count'))).text,
      '$live',
    );
    // Search, the filter, Live now, then each competition in seed order.
    double y(Finder f) => t.getTopLeft(f).dy;
    final order = [
      y(find.byKey(const Key('search-pill'))),
      y(find.byKey(const Key('sport-all'))),
      y(find.text('Live now')),
      for (final comp in c.read(competitionsProvider)) y(find.text(comp.name)),
    ];
    expect(order, [...order]..sort());
    expect(find.byType(LiveCard), findsWidgets);
  });

  testWidgets('followed teams lead the live rail', (t) async {
    phone(t, size: tall);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    final scores = await c.read(scoreRepositoryProvider.future);
    final live = fixtureIn(scores, Sport.cricket, Phase.live);
    await pumpScreen(t, c, const ScoresTab());
    final (c2, _) = await makeContainer(
      seed,
      signedIn: seed.profile,
      prefs: {
        Store.following: [live.homeId],
      },
    );
    await pumpScreen(t, c2, const ScoresTab());
    final first = t.widget<LiveCard>(find.byType(LiveCard).first);
    expect(first.fixtureId, live.id);
  });

  testWidgets('the sport filter narrows everything and is remembered', (
    t,
  ) async {
    phone(t, size: tall);
    final (c, store) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ScoresTab());
    final all = t.widgetList(find.byType(MatchRow)).length;
    await tapVisible(t, find.byKey(const Key('sport-cricket')));
    expect(c.read(sportFilterProvider), Sport.cricket);
    expect(store.string(Store.sport), 'cricket');
    expect(find.text('Super Twenty Series'), findsOneWidget);
    expect(find.text('Coastal Premier League'), findsNothing);
    expect(t.widgetList(find.byType(MatchRow)).length, lessThan(all));
    for (final row in t.widgetList<MatchRow>(find.byType(MatchRow))) {
      expect(row.fixtureId, startsWith('t20:'));
    }
    await tapVisible(t, find.byKey(const Key('sport-all')));
    expect(store.string(Store.sport), isNull);
  });

  testWidgets('when nothing is live it says so and names the next match', (
    t,
  ) async {
    phone(t, size: tall);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    final scores = await c.read(scoreRepositoryProvider.future);
    // Find a moment with no cricket being played.
    DateTime? quiet;
    for (var s = 0; s < 3600 && quiet == null; s += 5) {
      final at = testNow.add(Duration(seconds: s));
      final any = scores
          .fixtures(at)
          .any(
            (f) =>
                f.sport == Sport.cricket &&
                !at.isBefore(f.kickoff) &&
                at.isBefore(scores.endOf(f.id)!),
          );
      if (!any) quiet = at;
    }
    expect(quiet, isNotNull, reason: 'the cricket round has a gap');
    final (c2, _) = await makeContainer(
      seed,
      signedIn: seed.profile,
      now: quiet,
      prefs: {Store.sport: 'cricket'},
    );
    await pumpScreen(t, c2, const ScoresTab());
    expect(find.byKey(const Key('nothing-live')), findsOneWidget);
    expect(find.text('No cricket live right now'), findsOneWidget);
    expect(find.textContaining('starts in'), findsOneWidget);
    expect(find.byType(LiveCard), findsNothing);
  });

  testWidgets('a row shows the clock live, the time before, the mark after', (
    t,
  ) async {
    phone(t, size: tall);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    final scores = await c.read(scoreRepositoryProvider.future);
    final live = fixtureIn(scores, Sport.football, Phase.live);
    final soon = fixtureIn(scores, Sport.football, Phase.upcoming);
    final done = fixtureIn(scores, Sport.football, Phase.finished);
    await pumpScreen(
      t,
      c,
      ListView(
        children: [MatchRow(live.id), MatchRow(soon.id), MatchRow(done.id)],
      ),
    );
    Finder within(String id, Finder f) =>
        find.descendant(of: find.byKey(Key('match-$id')), matching: f);
    expect(within(live.id, find.text('LIVE')), findsOneWidget);
    expect(
      within(live.id, find.text(scores.clock(live.id, testNow))),
      findsOneWidget,
    );
    expect(within(soon.id, find.textContaining('in ')), findsOneWidget);
    expect(within(soon.id, find.byType(RollingNumber)), findsNothing);
    expect(within(done.id, find.text('FT')), findsOneWidget);
    expect(within(done.id, find.byType(RollingNumber)), findsNWidgets(2));
  });

  testWidgets('a score rolls when the clock moves on, and only then', (
    t,
  ) async {
    phone(t);
    // A basketball game always scores within a few seconds.
    final start = whenLive(league(seed), Sport.basketball);
    final clock = TestClock(start);
    final (c, _) = await makeContainer(
      seed,
      signedIn: seed.profile,
      clock: clock,
    );
    final scores = await c.read(scoreRepositoryProvider.future);
    final f = fixtureIn(scores, Sport.basketball, Phase.live, now: start);
    await pumpScreen(
      t,
      c,
      ListView(children: [MatchRow(f.id)]),
      reduceMotion: false,
    );
    final key = Key('score-${f.id}-home');
    final before = t.widget<RollingNumber>(find.byKey(key)).text;
    final state = t.state(find.byKey(Key('match-${f.id}')));
    clock.now = start.add(const Duration(seconds: 45));
    c.invalidate(nowProvider);
    // One frame for the providers to re-read the clock, one to rebuild.
    await t.pump();
    await t.pump();
    final after = scores.match(f.id, clock.now)!.score(Side.home).main;
    expect(after, isNot(before));
    expect(t.widget<RollingNumber>(find.byKey(key)).text, after);
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpAndSettle();
    // The row was updated in place, not rebuilt from scratch.
    expect(identical(t.state(find.byKey(Key('match-${f.id}'))), state), isTrue);
  });

  testWidgets('a card opens its match, and a crest on the board its team', (
    t,
  ) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ScoresTab());
    final card = t.widget<LiveCard>(find.byType(LiveCard).first);
    await t.tap(find.byType(LiveCard).first);
    await t.pumpAndSettle();
    expect(find.byType(MatchScreen), findsOneWidget);
    expect(
      t.widget<MatchScreen>(find.byType(MatchScreen)).fixtureId,
      card.fixtureId,
    );
    await t.tap(find.byKey(const Key('board-team-home')));
    await t.pumpAndSettle();
    expect(find.byType(TeamScreen), findsOneWidget);
  });

  testWidgets('the pill opens search', (t) async {
    phone(t);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ScoresTab());
    await t.tap(find.byKey(const Key('search-pill')));
    await t.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('nothing overflows on a small phone at a large text size', (
    t,
  ) async {
    phone(t, size: const Size(360, 3600));
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await warm(c);
    await t.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 3600),
          textScaler: TextScaler.linear(1.3),
        ),
        child: const SizedBox.shrink(),
      ),
    );
    t.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(t.platformDispatcher.clearAllTestValues);
    await pumpScreen(t, c, const ScoresTab(), mode: ThemeMode.dark);
    expect(t.takeException(), isNull);
  });
}
