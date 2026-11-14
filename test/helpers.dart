import 'dart:io';

import 'package:floodlight/config/app_theme.dart';
import 'package:floodlight/config/app_timing.dart';
import 'package:floodlight/config/motion.dart';
import 'package:floodlight/models/account.dart';
import 'package:floodlight/models/fixture.dart';
import 'package:floodlight/models/league.dart';
import 'package:floodlight/providers/account_providers.dart';
import 'package:floodlight/providers/core_providers.dart';
import 'package:floodlight/providers/session_providers.dart';
import 'package:floodlight/services/score_repository.dart';
import 'package:floodlight/services/seed.dart';
import 'package:floodlight/services/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The real seed, read from disk with dart:io. Call outside testWidgets: an
/// asset-bundle load inside the fake-async zone hangs every test after the
/// first in a file.
Seed readSeed() => Seed.fromSources({
  for (final f in Seed.files) f: File('assets/data/$f.json').readAsStringSync(),
});

/// No ambient loops (so pumpAndSettle settles) and no deliberate waits.
void quietMotion() {
  Motion.ambient = false;
  AppTiming.scale = 0;
}

/// An iPhone-sized surface. The 800x600 default hides phone layout bugs.
void phone(WidgetTester tester, {Size size = const Size(390, 844)}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

/// The fixed "now" every test runs at, unless it picks another. The league
/// is worked out from the clock, so at this moment the same matches are
/// always live, about to start and over.
final testNow = DateTime.utc(2026, 11, 14, 15, 2, 30);

/// A clock a test can move: `clock.now = ...` then pump.
class TestClock {
  TestClock(this.now);
  DateTime now;
  DateTime call() => now;
}

/// [now] is both the clock and the first-launch stamp unless
/// [firstLaunch] says otherwise.
Future<(ProviderContainer, Store)> makeContainer(
  Seed seed, {
  Map<String, Object> prefs = const {},
  UserProfile? signedIn,
  DateTime? now,
  DateTime? firstLaunch,
  TestClock? clock,
  List<Override> overrides = const [],
}) async {
  final at = now ?? clock?.now ?? testNow;
  SharedPreferences.setMockInitialValues({
    'flutter.${Store.seedStamp}':
        '${(firstLaunch ?? at).millisecondsSinceEpoch}',
    for (final e in prefs.entries) 'flutter.${e.key}': e.value,
  });
  final store = Store(await SharedPreferences.getInstance());
  if (signedIn != null) {
    await store.setJson(Store.session, {'email': signedIn.email});
  }
  final container = ProviderContainer(
    overrides: [
      storeProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(clock?.call ?? () => at),
      ...overrides,
      seedProvider.overrideWith((_) async => seed),
    ],
  );
  addTearDown(container.dispose);
  return (container, store);
}

/// Loads everything a screen may watch, so nothing first resolves during a
/// build.
Future<void> warm(ProviderContainer container) async {
  await container.read(seedProvider.future);
  await container.read(scoreRepositoryProvider.future);
  await container.read(authRepositoryProvider.future);
  await container.read(accountRepositoryProvider.future);
  await container.read(followingProvider.future);
  await container.read(picksProvider.future);
  await container.read(pinnedProvider.future);
  await container.read(alertPrefsProvider.future);
  await container.read(alertsReadProvider.future);
  await container.read(alertsClearedProvider.future);
  await container.read(recentSearchesProvider.future);
  await container.read(profileProvider.future);
}

/// Pumps [child] in a themed MaterialApp inside [container], with the
/// data already loaded. Reduce motion is on, so shader and particle
/// effects take their plain paths and everything settles.
Future<void> pumpScreen(
  WidgetTester tester,
  ProviderContainer container,
  Widget child, {
  ThemeMode mode = ThemeMode.light,
  bool reduceMotion = true,
}) async {
  await warm(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
          child: app!,
        ),
        // Tab pages live inside the shell's Scaffold in the app; give them
        // one here so toasts have somewhere to show.
        home: Scaffold(resizeToAvoidBottomInset: false, body: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

/// Taps something that may be off screen in a list.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The demo league on its own, for engine and model tests.
ScoreRepository league(Seed seed) => SimulatedScoreRepository(seed);

enum Phase { live, upcoming, finished }

/// The first fixture of [sport] in [phase] at [now].
Fixture fixtureIn(
  ScoreRepository scores,
  Sport sport,
  Phase phase, {
  DateTime? now,
}) {
  final at = now ?? testNow;
  return scores.fixtures(at).firstWhere((f) {
    if (f.sport != sport) return false;
    final end = scores.endOf(f.id)!;
    return switch (phase) {
      Phase.upcoming => at.isBefore(f.kickoff),
      Phase.live => !at.isBefore(f.kickoff) && at.isBefore(end),
      Phase.finished => !at.isBefore(end),
    };
  });
}

/// The first moment from [testNow] at which a match of [sport] is a good
/// minute into play, with a minute still to go.
DateTime whenLive(ScoreRepository scores, Sport sport) {
  for (var s = 0; s < 7200; s += 10) {
    final at = testNow.add(Duration(seconds: s));
    final ok = scores
        .fixtures(at)
        .any(
          (f) =>
              f.sport == sport &&
              at.difference(f.kickoff) > const Duration(seconds: 60) &&
              scores.endOf(f.id)!.difference(at) > const Duration(seconds: 120),
        );
    if (ok) return at;
  }
  throw StateError('no live ${sport.name}');
}
