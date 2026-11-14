import 'dart:io';

import 'package:floodlight/app.dart';
import 'package:floodlight/config/app_brand.dart';
import 'package:floodlight/config/app_timing.dart';
import 'package:floodlight/config/launch_hooks.dart';
import 'package:floodlight/models/league.dart';
import 'package:floodlight/providers/account_providers.dart';
import 'package:floodlight/providers/core_providers.dart';
import 'package:floodlight/screens/alerts/alerts_screen.dart';
import 'package:floodlight/screens/auth/auth_screen.dart';
import 'package:floodlight/screens/following/following_tab.dart';
import 'package:floodlight/screens/match/match_screen.dart';
import 'package:floodlight/screens/onboarding/onboarding_screen.dart';
import 'package:floodlight/screens/profile/profile_tab.dart';
import 'package:floodlight/screens/scores/scores_tab.dart';
import 'package:floodlight/screens/shell/main_shell.dart';
import 'package:floodlight/screens/splash/splash_overlay.dart';
import 'package:floodlight/screens/tables/tables_tab.dart';
import 'package:floodlight/services/store.dart';
import 'package:floodlight/widgets/match_island.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:floodlight/kit/kit.dart';

import 'helpers.dart';

Future<void> pumpApp(WidgetTester t, ProviderContainer c) async {
  await warm(c);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: FloodlightApp(),
      ),
    ),
  );
}

/// Steps past the splash in frames: one long pump would run its timeline,
/// its awaits and the first screen's entrance only once.
Future<void> pumpPastSplash(WidgetTester t) async {
  final frames = AppTiming.splashTotal.inMilliseconds ~/ 50 + 12;
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Finder tab(String label) => find.descendant(
  of: find.byType(LiquidGlassTabBar),
  matching: find.text(label),
);

void main() {
  final seed = readSeed();
  setUp(quietMotion);
  tearDown(() => AppTiming.scale = 0);

  group('first screen', () {
    testWidgets('a first launch opens on onboarding', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed);
      await pumpApp(t, c);
      await t.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('once onboarded, it opens on sign in', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, prefs: {Store.onboarded: '1'});
      await pumpApp(t, c);
      await t.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('a remembered session opens on Scores', (t) async {
      phone(t);
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpApp(t, c);
      await t.pumpAndSettle();
      expect(find.byType(ScoresTab), findsOneWidget);
      expect(find.byType(LiquidGlassTabBar), findsOneWidget);
    });
  });

  group('splash', () {
    testWidgets('plays over a blank page, then hands over without a remount', (
      t,
    ) async {
      phone(t);
      AppTiming.scale = 1;
      final (c, _) = await makeContainer(seed, signedIn: seed.profile);
      await pumpApp(t, c);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.byType(SplashOverlay), findsOneWidget);
      expect(find.byType(ScoresTab), findsNothing);
      // The tagline sits on its own Material: no debug underline.
      final style = DefaultTextStyle.of(
        t.element(find.text(AppBrand.tagline)),
      ).style;
      expect(style.decoration, isNot(TextDecoration.underline));

      // Step until the first screen is mounted under the leaving splash.
      for (
        var i = 0;
        i < 90 && c.read(splashPhaseProvider) != SplashPhase.leaving;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(c.read(splashPhaseProvider), SplashPhase.leaving);
      final during = t.state(find.byType(MainShell));
      await pumpPastSplash(t);
      expect(c.read(splashPhaseProvider), SplashPhase.done);
      expect(find.byType(SplashOverlay), findsNothing);
      // The same State before and after: the first screen was not rebuilt
      // from scratch, so its entrance cannot have played twice.
      expect(identical(t.state(find.byType(MainShell)), during), isTrue);
    });
  });

  group('shell', () {
    testWidgets('tabs switch and Alerts opens inside the tab', (t) async {
      phone(t);
      final (c, _) = await makeContainer(
        seed,
        signedIn: seed.profile,
        firstLaunch: testNow.subtract(const Duration(minutes: 10)),
      );
      await pumpApp(t, c);
      await t.pumpAndSettle();
      await t.tap(tab('Tables'));
      await t.pumpAndSettle();
      expect(c.read(shellTabProvider), ShellTab.tables);
      expect(find.byType(TablesTab), findsOneWidget);
      await t.tap(tab('Following'));
      await t.pumpAndSettle();
      expect(find.byType(FollowingTab), findsOneWidget);
      await t.tap(tab('You'));
      await t.pumpAndSettle();
      expect(find.byType(ProfileTab), findsOneWidget);

      // The badge counts what has not been opened.
      final unread = c.read(unreadAlertsProvider);
      expect(unread, greaterThan(0));
      expect(
        find.descendant(
          of: find.byKey(const Key('alerts-badge')),
          matching: find.text('$unread'),
        ),
        findsOneWidget,
      );
      await t.tap(find.byIcon(Icons.notifications_none_rounded).last);
      await t.pumpAndSettle();
      expect(find.byType(AlertsScreen), findsOneWidget);
      // The bar is still there: the page opened inside the tab.
      expect(find.byType(LiquidGlassTabBar), findsOneWidget);
    });

    testWidgets('a followed team that is playing rides in the live pill', (
      t,
    ) async {
      phone(t);
      final scores = league(seed);
      final at = whenLive(scores, Sport.football);
      final f = fixtureIn(scores, Sport.football, Phase.live, now: at);
      final (c, _) = await makeContainer(
        seed,
        signedIn: seed.profile,
        now: at,
        prefs: {
          Store.following: [f.homeId],
        },
      );
      await pumpApp(t, c);
      await t.pumpAndSettle();
      expect(c.read(islandMatchProvider), f.id);
      expect(find.byType(MatchIsland), findsOneWidget);
      // Open it, then tap through to the match: the pill steps aside.
      await t.tap(find.byKey(const Key('match-island')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('match-island')));
      await t.pumpAndSettle();
      expect(find.byType(MatchScreen), findsOneWidget);
      expect(find.byType(MatchIsland), findsNothing);
      expect(find.byType(LiquidGlassTabBar), findsOneWidget);
      // Let the pill's own spring run out.
      await t.pump(const Duration(seconds: 2));
    });

    testWidgets('the journey: sign in, open a match, pin it, go back', (
      t,
    ) async {
      phone(t);
      final (c, _) = await makeContainer(
        seed,
        prefs: {Store.onboarded: '1', Store.following: <String>[]},
      );
      await pumpApp(t, c);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(AuthKeys.email), 'ada@example.com');
      await t.enterText(find.byKey(AuthKeys.password), 'anything');
      await tapVisible(t, find.byKey(AuthKeys.submit));
      expect(find.byType(ScoresTab), findsOneWidget);
      expect(find.byType(MatchIsland), findsNothing);

      final scores = c.read(scoresProvider)!;
      final live = fixtureIn(scores, Sport.football, Phase.live);
      await tapVisible(t, find.byKey(Key('match-${live.id}')));
      expect(find.byType(MatchScreen), findsOneWidget);
      await t.tap(find.byKey(const Key('pin-match')));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Back'));
      await t.pumpAndSettle();
      expect(find.byType(MatchScreen), findsNothing);
      // Back on Scores, the pinned match is in the pill.
      expect(find.byType(MatchIsland), findsOneWidget);
      expect(c.read(islandMatchProvider), live.id);
    });
  });

  group('the source', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    test('no em dashes in anything a person can read', () {
      for (final f in [
        ...sources,
        ...Directory('assets/data').listSync().whereType<File>(),
      ]) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i].trimLeft();
          if (line.startsWith('//')) continue;
          expect(line.contains('—'), isFalse, reason: '${f.path}:${i + 1}');
        }
      }
    });

    test('launch hooks are off unless asked for', () {
      expect(LaunchHooks.start, isEmpty);
      expect(
        File('lib/config/launch_hooks.dart').readAsStringSync(),
        contains("defaultValue: ''"),
      );
    });

    test('colours are defined in the palette and nowhere else', () {
      final allowed = {
        'lib/config/palette.dart',
        // Apple's and Google's marks are fixed by their guidelines.
        'lib/widgets/social_buttons.dart',
      };
      final literal = RegExp(r'Color\(0x|Colors\.(?!transparent)');
      for (final f in sources) {
        if (allowed.contains(f.path)) continue;
        // The copied-in components: they take the app's colours as arguments
        // and only keep neutral defaults of their own.
        if (f.path.startsWith('lib/kit/')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trimLeft().startsWith('//')) continue;
          expect(
            literal.hasMatch(lines[i]),
            isFalse,
            reason: '${f.path}:${i + 1} ${lines[i].trim()}',
          );
        }
      }
    });

    test('only the repositories read the seed or run the engine', () {
      for (final f in sources) {
        if (f.path.startsWith('lib/services/') ||
            f.path.startsWith('lib/engine/') ||
            f.path.startsWith('lib/kit/') ||
            f.path == 'lib/providers/core_providers.dart') {
          continue;
        }
        final imports = f.readAsLinesSync().where(
          (l) => l.startsWith('import '),
        );
        for (final line in imports) {
          expect(line.contains('engine/'), isFalse, reason: f.path);
          expect(line.contains('services/seed.dart'), isFalse, reason: f.path);
        }
      }
    });

    test('no source file is longer than 500 lines', () {
      for (final f in sources) {
        expect(
          f.readAsLinesSync().length,
          lessThanOrEqualTo(500),
          reason: f.path,
        );
      }
    });
  });
}
