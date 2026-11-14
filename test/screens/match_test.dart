import 'package:floodlight/models/league.dart';
import 'package:floodlight/models/match.dart';
import 'package:floodlight/models/pick.dart';
import 'package:floodlight/providers/account_providers.dart';
import 'package:floodlight/providers/core_providers.dart';
import 'package:floodlight/screens/match/basketball_sections.dart';
import 'package:floodlight/screens/match/cricket_sections.dart';
import 'package:floodlight/screens/match/football_sections.dart';
import 'package:floodlight/screens/match/match_screen.dart';
import 'package:floodlight/screens/match/match_tabs.dart';
import 'package:floodlight/services/store.dart';
import 'package:floodlight/widgets/match_island.dart';
import 'package:floodlight/widgets/rolling_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const tall = Size(390, 3000);

void main() {
  final seed = readSeed();
  setUp(quietMotion);

  Future<void> tab(WidgetTester t, String label) async {
    await t.tap(find.byKey(Key('match-tab-$label')));
    await t.pumpAndSettle();
  }

  String boardScore(WidgetTester t, Side s) =>
      t.widget<RollingNumber>(find.byKey(Key('board-score-${s.name}'))).text;

  group('a football match', () {
    testWidgets('shows the board, then its four tabs', (t) async {
      phone(t, size: tall);
      final at = whenLive(league(seed), Sport.football);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile, now: at);
      final scores = await c.read(scoreRepositoryProvider.future);
      final f = fixtureIn(scores, Sport.football, Phase.live, now: at);
      final m = scores.match(f.id, at)!;
      await pumpScreen(t, c, MatchScreen(fixtureId: f.id));
      expect(boardScore(t, Side.home), m.score(Side.home).main);
      expect(boardScore(t, Side.away), m.score(Side.away).main);
      expect(find.text(m.headline), findsOneWidget);
      expect(find.text(scores.clock(f.id, at)), findsWidgets);
      expect(find.byType(MomentumPanel), findsOneWidget);
      expect(find.byKey(const Key('key-moments')), findsOneWidget);
      // Picks close at the start.
      expect(find.byKey(const Key('make-pick')), findsNothing);
      expect(find.textContaining('Picks closed'), findsOneWidget);

      await tab(t, 'Stats');
      expect(find.byKey(const Key('stat-Possession')), findsOneWidget);
      expect(find.byKey(const Key('stat-Expected goals')), findsOneWidget);

      await tab(t, 'Line-ups');
      expect(find.byType(LineupsView), findsOneWidget);
      expect(find.byKey(const Key('pitch')), findsOneWidget);
      // Twenty two on the pitch, each named.
      expect(
        find.descendant(
          of: find.byKey(const Key('pitch')),
          matching: find.byType(Semantics),
        ),
        findsAtLeastNWidgets(22),
      );

      await tab(t, 'Feed');
      expect(find.byKey(const Key('feed-list')), findsOneWidget);
      expect(find.text('Kick-off'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('a basketball game', () {
    testWidgets('has quarters, a lead tracker and a box score', (t) async {
      phone(t, size: tall);
      final at = whenLive(league(seed), Sport.basketball);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile, now: at);
      final scores = await c.read(scoreRepositoryProvider.future);
      final f = fixtureIn(scores, Sport.basketball, Phase.live, now: at);
      await pumpScreen(t, c, MatchScreen(fixtureId: f.id));
      expect(find.byType(QuartersPanel), findsOneWidget);
      expect(find.byType(LeadPanel), findsOneWidget);
      await tab(t, 'Box score');
      expect(find.byKey(const Key('box-score')), findsOneWidget);
      final home = scores.teams[f.homeId]!, away = scores.teams[f.awayId]!;
      expect(find.byKey(Key('box-${home.squad.first.id}')), findsOneWidget);
      await t.tap(find.byKey(const Key('side-away')));
      await t.pumpAndSettle();
      expect(find.byKey(Key('box-${away.squad.first.id}')), findsOneWidget);
      expect(find.byKey(Key('box-${home.squad.first.id}')), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('a cricket match', () {
    testWidgets('shows the middle, the over and the full card', (t) async {
      phone(t, size: tall);
      final at = whenLive(league(seed), Sport.cricket);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile, now: at);
      final scores = await c.read(scoreRepositoryProvider.future);
      final f = fixtureIn(scores, Sport.cricket, Phase.live, now: at);
      await pumpScreen(t, c, MatchScreen(fixtureId: f.id));
      expect(find.byType(CreasePanel), findsOneWidget);
      expect(find.byKey(const Key('over-strip')), findsOneWidget);
      expect(find.text('Run rate'), findsOneWidget);
      expect(find.byType(WormPanel), findsOneWidget);
      await tab(t, 'Scorecard');
      expect(find.byKey(const Key('batting-card')), findsOneWidget);
      expect(find.byKey(const Key('bowling-card')), findsOneWidget);
      // The side still to bat says so.
      final m = scores.match(f.id, at)!;
      if (m.score(Side.home).main.isEmpty || m.score(Side.away).main.isEmpty) {
        final waiting = m.score(Side.home).main.isEmpty ? 'home' : 'away';
        await t.tap(find.byKey(Key('side-$waiting')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('yet-to-bat')), findsOneWidget);
      }
      await tab(t, 'Feed');
      // Newest first and built lazily: the latest ball is there, the toss
      // is two hundred lines down and not built yet.
      expect(find.byType(FeedLine), findsWidgets);
      expect(
        t.widget<FeedLine>(find.byType(FeedLine).first).item.id,
        m.feed.last.id,
      );
      expect(t.takeException(), isNull);
    });

    testWidgets('a ball bowled moves the numbers without moving the page', (
      t,
    ) async {
      phone(t);
      final at = whenLive(league(seed), Sport.cricket);
      final clock = TestClock(at);
      final (c, _) = await makeContainer(
        seed,
        signedIn: seed.profile,
        clock: clock,
      );
      final scores = await c.read(scoreRepositoryProvider.future);
      final f = fixtureIn(scores, Sport.cricket, Phase.live, now: at);
      await pumpScreen(t, c, MatchScreen(fixtureId: f.id), reduceMotion: false);
      final panel = t.getRect(find.byType(CreasePanel));
      final before = scores.match(f.id, at)!.revision;
      clock.now = at.add(const Duration(seconds: 9));
      c.invalidate(nowProvider);
      await t.pump();
      await t.pump();
      expect(scores.match(f.id, clock.now)!.revision, greaterThan(before));
      await t.pump(const Duration(milliseconds: 200));
      // Mid-roll: the panel is exactly where it was.
      expect(t.getRect(find.byType(CreasePanel)).topLeft, panel.topLeft);
      expect(t.getRect(find.byType(CreasePanel)).width, panel.width);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });

  group('before the start', () {
    testWidgets('the board counts down and shows how the sides come in', (
      t,
    ) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      final scores = await c.read(scoreRepositoryProvider.future);
      final f = fixtureIn(scores, Sport.football, Phase.upcoming);
      await pumpScreen(t, c, MatchScreen(fixtureId: f.id));
      expect(find.byKey(const Key('board-countdown')), findsOneWidget);
      expect(find.byType(FormPanel), findsOneWidget);
      expect(find.byType(MomentumPanel), findsNothing);
      await tab(t, 'Stats');
      expect(find.text('The numbers start with the match.'), findsOneWidget);
      await tab(t, 'Feed');
      expect(find.text('Commentary starts with the match.'), findsOneWidget);
    });

    testWidgets('a pick is made, changed, and names what is missing', (
      t,
    ) async {
      phone(t, size: tall);
      final (c, store) = await makeContainer(
        seed,
        signedIn: seed.profile,
        prefs: {Store.picks: '[]'},
      );
      final scores = await c.read(scoreRepositoryProvider.future);
      final f = fixtureIn(scores, Sport.football, Phase.upcoming);
      await pumpScreen(t, c, MatchScreen(fixtureId: f.id));
      await t.tap(find.byKey(const Key('make-pick')));
      await t.pumpAndSettle();
      // Football offers the draw as well.
      expect(find.byKey(const Key('pick-draw')), findsOneWidget);
      await t.tap(find.byKey(const Key('save-pick')));
      await t.pumpAndSettle();
      expect(find.text('Choose who wins first.'), findsOneWidget);
      expect(c.read(picksProvider).value, isEmpty);

      await t.tap(find.byKey(const Key('pick-away')));
      await t.pump();
      await t.tap(find.byKey(const Key('save-pick')));
      await t.pumpAndSettle();
      expect(c.read(pickForProvider(f.id))!.choice, PickChoice.away);
      expect(store.string(Store.picks), contains(f.id));
      expect(find.text(scores.teams[f.awayId]!.name), findsWidgets);
      expect(find.text('Locked in until the start'), findsOneWidget);

      await t.tap(find.byKey(const Key('change-pick')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('pick-home')));
      await t.pump();
      await t.tap(find.byKey(const Key('save-pick')));
      await t.pumpAndSettle();
      expect(c.read(picksProvider).value!.length, 1);
      expect(c.read(pickForProvider(f.id))!.choice, PickChoice.home);
    });

    testWidgets('basketball has no draw to pick', (t) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(
        seed,
        signedIn: seed.profile,
        prefs: {Store.picks: '[]'},
      );
      final scores = await c.read(scoreRepositoryProvider.future);
      final f = fixtureIn(scores, Sport.basketball, Phase.upcoming);
      await pumpScreen(t, c, MatchScreen(fixtureId: f.id));
      await t.tap(find.byKey(const Key('make-pick')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('pick-draw')), findsNothing);
      expect(find.byKey(const Key('pick-home')), findsOneWidget);
    });
  });

  group('after the end', () {
    testWidgets('a pick is right or wrong, worked out from the result', (
      t,
    ) async {
      phone(t, size: tall);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await warm(c);
      final picks = c.read(picksProvider).value!;
      final scores = c.read(scoresProvider)!;
      final results = {
        for (final p in picks) p.resultFor(scores.match(p.fixtureId, testNow)!),
      };
      // The seed opens with one of each.
      expect(results, {PickResult.open, PickResult.won, PickResult.lost});
      final won = picks.firstWhere(
        (p) =>
            p.resultFor(scores.match(p.fixtureId, testNow)!) == PickResult.won,
      );
      await pumpScreen(t, c, MatchScreen(fixtureId: won.fixtureId));
      expect(find.text('You called it'), findsOneWidget);
      expect(scores.match(won.fixtureId, testNow)!.stage, MatchStage.finished);
    });
  });

  group('the live pill', () {
    testWidgets('pinning keeps a match, and unpinning lets it go', (t) async {
      phone(t);
      final (c, store) = await makeContainer(seed, signedIn: seed.profile);
      final scores = await c.read(scoreRepositoryProvider.future);
      final f = fixtureIn(scores, Sport.football, Phase.live);
      await pumpScreen(t, c, MatchScreen(fixtureId: f.id));
      await t.tap(find.byKey(const Key('pin-match')));
      await t.pumpAndSettle();
      expect(c.read(pinnedProvider).value, f.id);
      expect(store.string(Store.pinned), f.id);
      await t.tap(find.byKey(const Key('pin-match')));
      await t.pumpAndSettle();
      expect(c.read(pinnedProvider).value, isNull);
    });

    testWidgets('opens to the scoreboard, and can be waved away', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      final scores = await c.read(scoreRepositoryProvider.future);
      final f = fixtureIn(scores, Sport.football, Phase.live);
      await warm(c);
      await c.read(pinnedProvider.notifier).set(f.id);
      await pumpScreen(t, c, Center(child: MatchIsland(fixtureId: f.id)));
      expect(find.text(scores.teams[f.homeId]!.short), findsOneWidget);
      await t.tap(find.byKey(const Key('match-island')));
      await t.pumpAndSettle();
      expect(find.text(scores.teams[f.homeId]!.name), findsOneWidget);
      await t.tap(find.byKey(const Key('island-close')));
      await t.pumpAndSettle();
      expect(c.read(pinnedProvider).value, isNull);
      expect(c.read(islandDismissedProvider), contains(f.id));
    });
  });
}
