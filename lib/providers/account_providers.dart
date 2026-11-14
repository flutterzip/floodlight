import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ids.dart';
import '../models/league.dart';
import '../models/match.dart';
import '../models/pick.dart';
import '../services/account_repository.dart';
import 'core_providers.dart';
import 'score_providers.dart';

Future<AccountRepository> _repo(Ref ref) =>
    ref.read(accountRepositoryProvider.future);

/// The teams the person follows, most recent first.
class FollowingNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async =>
      (await ref.watch(accountRepositoryProvider.future)).following();

  Future<void> _set(List<String> next) async {
    final before = state;
    state = AsyncData(next);
    try {
      await (await _repo(ref)).setFollowing(next);
    } catch (_) {
      state = before;
      rethrow;
    }
  }

  Future<void> follow(String teamId) {
    final now = state.valueOrNull ?? const <String>[];
    if (now.contains(teamId)) return Future.value();
    return _set([teamId, ...now]);
  }

  Future<void> unfollow(String teamId) => _set([
    for (final id in state.valueOrNull ?? const <String>[])
      if (id != teamId) id,
  ]);

  /// Puts a team back where it was, for Undo.
  Future<void> restore(String teamId, int at) {
    final now = [...state.valueOrNull ?? const <String>[]];
    if (now.contains(teamId)) return Future.value();
    return _set(now..insert(at.clamp(0, now.length), teamId));
  }
}

final followingProvider =
    AsyncNotifierProvider<FollowingNotifier, List<String>>(
      FollowingNotifier.new,
    );

final isFollowingProvider = Provider.family<bool, String>(
  (ref, teamId) =>
      ref.watch(followingProvider).valueOrNull?.contains(teamId) ?? false,
);

/// The person's picks, newest first.
class PicksNotifier extends AsyncNotifier<List<Pick>> {
  @override
  Future<List<Pick>> build() async =>
      (await ref.watch(accountRepositoryProvider.future)).picks();

  List<Pick> get _now => state.valueOrNull ?? const [];

  /// Makes a pick for [fixtureId], or changes the one already there.
  Future<void> choose(String fixtureId, PickChoice choice) async {
    final before = state;
    final existing = _now.where((p) => p.fixtureId == fixtureId).firstOrNull;
    final pick =
        existing?.copyWith(choice: choice) ??
        Pick(
          id: Ids.next('pick'),
          fixtureId: fixtureId,
          choice: choice,
          madeAt: ref.read(clockProvider)(),
        );
    state = AsyncData(
      existing == null
          ? [pick, ..._now]
          : [for (final p in _now) p.id == pick.id ? pick : p],
    );
    try {
      await (await _repo(ref)).savePick(pick);
    } catch (_) {
      state = before;
      rethrow;
    }
  }

  /// Removes a pick and returns where it was, for Undo.
  Future<int> remove(String id) async {
    final before = state;
    final at = _now.indexWhere((p) => p.id == id);
    if (at < 0) return -1;
    state = AsyncData([..._now]..removeAt(at));
    try {
      await (await _repo(ref)).deletePick(id);
    } catch (_) {
      state = before;
      rethrow;
    }
    return at;
  }

  Future<void> restore(Pick pick, int at) async {
    if (_now.any((p) => p.id == pick.id)) return;
    state = AsyncData([..._now]..insert(at.clamp(0, _now.length), pick));
    await (await _repo(ref)).savePick(pick, at: at);
  }
}

final picksProvider = AsyncNotifierProvider<PicksNotifier, List<Pick>>(
  PicksNotifier.new,
);

final pickForProvider = Provider.family<Pick?, String>((ref, fixtureId) {
  for (final p in ref.watch(picksProvider).valueOrNull ?? const <Pick>[]) {
    if (p.fixtureId == fixtureId) return p;
  }
  return null;
});

/// How a pick stands: open until its match ends, then right or wrong.
final pickResultProvider = Provider.family<PickResult, String>((
  ref,
  fixtureId,
) {
  final pick = ref.watch(pickForProvider(fixtureId));
  final match = ref.watch(matchProvider(fixtureId));
  if (pick == null || match == null) return PickResult.open;
  return pick.resultFor(match);
});

/// The record, added up from the picks and their matches.
typedef PickRecord = ({int won, int lost, int open, int streak});

final pickRecordProvider = Provider<PickRecord>((ref) {
  final picks = ref.watch(picksProvider).valueOrNull ?? const <Pick>[];
  var won = 0, lost = 0, open = 0, streak = 0;
  var counting = true;
  // Newest first: the streak is the run of right calls from the top.
  final settled = [...picks]..sort((a, b) => b.madeAt.compareTo(a.madeAt));
  for (final p in settled) {
    switch (ref.watch(pickResultProvider(p.fixtureId))) {
      case PickResult.won:
        won++;
        if (counting) streak++;
      case PickResult.lost:
        lost++;
        counting = false;
      case PickResult.open:
        open++;
    }
  }
  return (won: won, lost: lost, open: open, streak: streak);
});

/// The match kept in the live pill above every tab.
class PinnedNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async =>
      (await ref.watch(accountRepositoryProvider.future)).pinnedMatch();

  Future<void> set(String? fixtureId) async {
    state = AsyncData(fixtureId);
    await (await _repo(ref)).setPinnedMatch(fixtureId);
  }
}

final pinnedProvider = AsyncNotifierProvider<PinnedNotifier, String?>(
  PinnedNotifier.new,
);

class AlertPrefsNotifier extends AsyncNotifier<AlertPrefs> {
  @override
  Future<AlertPrefs> build() async =>
      (await ref.watch(accountRepositoryProvider.future)).alertPrefs();

  Future<void> set(AlertPrefs prefs) async {
    state = AsyncData(prefs);
    await (await _repo(ref)).setAlertPrefs(prefs);
  }
}

final alertPrefsProvider =
    AsyncNotifierProvider<AlertPrefsNotifier, AlertPrefs>(
      AlertPrefsNotifier.new,
    );

/// A set of ids kept through the account repository.
abstract class _IdSetNotifier extends AsyncNotifier<Set<String>> {
  Future<Set<String>> read(AccountRepository repo);
  Future<void> write(AccountRepository repo, Set<String> ids);

  @override
  Future<Set<String>> build() async =>
      read(await ref.watch(accountRepositoryProvider.future));

  Future<void> addAll(Iterable<String> ids) async {
    final next = {...state.valueOrNull ?? const <String>{}, ...ids};
    state = AsyncData(next);
    await write(await _repo(ref), next);
  }

  Future<void> remove(String id) async {
    final next = {...state.valueOrNull ?? const <String>{}}..remove(id);
    state = AsyncData(next);
    await write(await _repo(ref), next);
  }
}

class AlertsReadNotifier extends _IdSetNotifier {
  @override
  Future<Set<String>> read(AccountRepository repo) => repo.alertsRead();
  @override
  Future<void> write(AccountRepository repo, Set<String> ids) =>
      repo.setAlertsRead(ids);
}

class AlertsClearedNotifier extends _IdSetNotifier {
  @override
  Future<Set<String>> read(AccountRepository repo) => repo.alertsCleared();
  @override
  Future<void> write(AccountRepository repo, Set<String> ids) =>
      repo.setAlertsCleared(ids);
}

final alertsReadProvider =
    AsyncNotifierProvider<AlertsReadNotifier, Set<String>>(
      AlertsReadNotifier.new,
    );
final alertsClearedProvider =
    AsyncNotifierProvider<AlertsClearedNotifier, Set<String>>(
      AlertsClearedNotifier.new,
    );

/// The alerts, newest first. Equal while the same alerts are in it, so the
/// inbox and its badge do not rebuild every second.
@immutable
class AlertList {
  AlertList(this.items) : _key = items.map((a) => a.id).join(',');
  final List<Alert> items;
  final String _key;

  @override
  bool operator ==(Object other) => other is AlertList && other._key == _key;

  @override
  int get hashCode => _key.hashCode;
}

/// How far back the inbox reaches on a first launch.
const _alertWindow = Duration(minutes: 20);

/// Alerts are not stored. Each one is a moment in a followed team's match:
/// the start, a goal or a milestone, the result. Only which have been read or
/// cleared is kept.
final alertsProvider = Provider<AlertList>((ref) {
  final scores = ref.watch(scoresProvider);
  final following = ref.watch(followingProvider).valueOrNull ?? const [];
  if (scores == null || following.isEmpty) return AlertList(const []);
  final prefs = ref.watch(alertPrefsProvider).valueOrNull ?? const AlertPrefs();
  final cleared = ref.watch(alertsClearedProvider).valueOrNull ?? const {};
  final since = ref.watch(seedStampProvider).subtract(_alertWindow);
  final board = ref.watch(boardProvider);
  final out = <Alert>[];
  for (final f in [...board.live, ...board.finished]) {
    final teamId = following.where(f.involves).firstOrNull;
    if (teamId == null) continue;
    final m = ref.watch(matchProvider(f.id));
    if (m == null) continue;
    final feed = m.feed;
    for (var i = 0; i < feed.length; i++) {
      final item = feed[i];
      if (!item.major) continue;
      final last = m.stage == MatchStage.finished && i == feed.length - 1;
      // A wicket matters in the match, but twenty of them is not an inbox.
      // Cricket alerts on fifties and the change of innings instead.
      final kind = last
          ? AlertKind.result
          : item.kind == FeedKind.period
          ? (item.at == Duration.zero
                ? AlertKind.start
                : (m.sport == Sport.cricket ? AlertKind.score : null))
          : item.kind == FeedKind.wicket
          ? null
          : AlertKind.score;
      if (kind == null) continue;
      if (!switch (kind) {
        AlertKind.start => prefs.starts,
        AlertKind.score => prefs.scores,
        AlertKind.result => prefs.results,
      }) {
        continue;
      }
      final at = f.kickoff.add(item.at);
      final id = '${f.id}/${item.id}';
      if (at.isBefore(since) || cleared.contains(id)) continue;
      out.add(
        Alert(
          id: id,
          fixtureId: f.id,
          kind: kind,
          teamId: teamId,
          at: at,
          title: switch (kind) {
            AlertKind.start => '${m.home.name} v ${m.away.name} is under way',
            AlertKind.result => m.headline,
            AlertKind.score => item.title,
          },
          body: switch (kind) {
            AlertKind.start => item.detail,
            AlertKind.result =>
              '${m.home.short} ${m.score(Side.home).main}, '
                  '${m.away.short} ${m.score(Side.away).main}',
            AlertKind.score => item.detail,
          },
        ),
      );
    }
  }
  return AlertList(out..sort((a, b) => b.at.compareTo(a.at)));
});

/// Anything older than this at first launch is taken as already seen, so
/// a new install opens with a handful of alerts, not a backlog.
const _freshWindow = Duration(minutes: 3);

/// The ids of the alerts not yet opened.
final unreadAlertIdsProvider = Provider<Set<String>>((ref) {
  final read = ref.watch(alertsReadProvider).valueOrNull ?? const {};
  final fresh = ref.watch(seedStampProvider).subtract(_freshWindow);
  return {
    for (final a in ref.watch(alertsProvider).items)
      if (!read.contains(a.id) && !a.at.isBefore(fresh)) a.id,
  };
});

final unreadAlertsProvider = Provider<int>(
  (ref) => ref.watch(unreadAlertIdsProvider).length,
);

class RecentSearchesNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async =>
      (await ref.watch(accountRepositoryProvider.future)).recentSearches();

  Future<void> _set(List<String> next) async {
    state = AsyncData(next);
    await (await _repo(ref)).setRecentSearches(next);
  }

  Future<void> add(String term) {
    final t = term.trim();
    if (t.isEmpty) return Future.value();
    final rest = [
      for (final s in state.valueOrNull ?? const <String>[])
        if (s.toLowerCase() != t.toLowerCase()) s,
    ];
    return _set([t, ...rest].take(6).toList());
  }

  Future<void> remove(String term) => _set([
    for (final s in state.valueOrNull ?? const <String>[])
      if (s != term) s,
  ]);

  Future<void> clear() => _set(const []);
}

final recentSearchesProvider =
    AsyncNotifierProvider<RecentSearchesNotifier, List<String>>(
      RecentSearchesNotifier.new,
    );
