import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_timing.dart';
import '../config/motion.dart';
import '../services/account_repository.dart';
import '../services/auth_repository.dart';
import '../services/score_repository.dart';
import '../services/seed.dart';
import '../services/store.dart';

// ---------------------------------------------------------------------------
// The data switchboard.
//
// Every screen gets its data from one of the three repositories below, and
// nothing else in lib/ reads the seed or runs the match engine. To connect
// a real backend, write the Remote* class sketched at the bottom of each
// repository file (they reuse every model's fromJson, because the seed
// files already use the API's JSON shapes) and return it here instead of
// the Simulated, Local or Demo one. No widget, provider or model changes.
// ---------------------------------------------------------------------------

/// Overridden in `main` with the loaded instance, and in tests with one
/// backed by `SharedPreferences.setMockInitialValues`.
final storeProvider = Provider<Store>(
  (_) => throw UnimplementedError('storeProvider must be overridden'),
);

/// The bundled demo data. Only the Local and Demo repositories read it.
final seedProvider = FutureProvider<Seed>((_) => Seed.load());

/// The time, as a provider, so tests can stand at any second of a match.
final clockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// The heartbeat: once a second while the app is in use. Still in tests,
/// which move the clock themselves.
final tickProvider = StreamProvider<int>((ref) {
  if (!Motion.ambient) return const Stream.empty();
  return Stream.periodic(AppTiming.tick, (i) => i);
});

/// The time now, re-read on every tick. Everything live hangs off this one
/// provider, so the whole app steps forward together.
final nowProvider = Provider<DateTime>((ref) {
  ref.watch(tickProvider);
  return ref.watch(clockProvider)();
});

/// The time to the minute, for things that only change slowly.
final minuteProvider = Provider<DateTime>((ref) {
  final now = ref.watch(nowProvider);
  return DateTime.fromMillisecondsSinceEpoch(
    now.millisecondsSinceEpoch ~/ 60000 * 60000,
    isUtc: now.isUtc,
  );
});

/// When the app was first opened, or last reset. Seeded picks and the first
/// alerts are placed relative to it.
class SeedStampNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final store = ref.watch(storeProvider);
    final saved = int.tryParse(store.string(Store.seedStamp) ?? '');
    if (saved != null) return DateTime.fromMillisecondsSinceEpoch(saved);
    final now = ref.read(clockProvider)();
    store.setString(Store.seedStamp, '${now.millisecondsSinceEpoch}');
    return now;
  }
}

final seedStampProvider = NotifierProvider<SeedStampNotifier, DateTime>(
  SeedStampNotifier.new,
);

final scoreRepositoryProvider = FutureProvider<ScoreRepository>(
  (ref) async => SimulatedScoreRepository(await ref.watch(seedProvider.future)),
);

final authRepositoryProvider = FutureProvider<AuthRepository>(
  (ref) async => DemoAuthRepository(await ref.watch(seedProvider.future)),
);

final accountRepositoryProvider = FutureProvider<AccountRepository>(
  (ref) async => LocalAccountRepository(
    await ref.watch(seedProvider.future),
    ref.watch(storeProvider),
    scores: await ref.watch(scoreRepositoryProvider.future),
    firstLaunch: ref.watch(seedStampProvider),
  ),
);

/// The scores, once they have loaded. The splash waits for them, so every
/// screen after it can read this without a loading state.
final scoresProvider = Provider<ScoreRepository?>(
  (ref) => ref.watch(scoreRepositoryProvider).valueOrNull,
);
