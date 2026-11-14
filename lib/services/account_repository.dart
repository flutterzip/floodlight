import '../models/account.dart';
import '../models/match.dart';
import '../models/pick.dart';
import 'score_repository.dart';
import 'seed.dart';
import 'store.dart';

/// The signed-in person's side of the app: their details, the teams they
/// follow, their picks, the match they have pinned and their alerts. Async
/// throughout, so a backend drops in without touching a widget.
abstract interface class AccountRepository {
  Future<UserProfile> profile();
  Future<UserProfile> updateProfile(UserProfile profile);

  /// Team ids, most recently followed first.
  Future<List<String>> following();
  Future<void> setFollowing(List<String> teamIds);

  Future<List<Pick>> picks();

  /// Adds the pick, or replaces the one with the same id.
  Future<void> savePick(Pick pick, {int? at});
  Future<void> deletePick(String id);

  Future<String?> pinnedMatch();
  Future<void> setPinnedMatch(String? fixtureId);

  Future<AlertPrefs> alertPrefs();
  Future<void> setAlertPrefs(AlertPrefs prefs);

  /// Ids of alerts that have been opened, and of ones cleared away.
  Future<Set<String>> alertsRead();
  Future<void> setAlertsRead(Set<String> ids);
  Future<Set<String>> alertsCleared();
  Future<void> setAlertsCleared(Set<String> ids);

  Future<List<String>> recentSearches();
  Future<void> setRecentSearches(List<String> terms);
}

class LocalAccountRepository implements AccountRepository {
  LocalAccountRepository(
    this._seed,
    this._store, {
    required ScoreRepository scores,
    required DateTime firstLaunch,
  }) : _picks = StoredList(
         _store,
         Store.picks,
         seed: () => seedPicks(_seed, scores, firstLaunch),
         decode: Pick.fromJson,
         encode: (p) => p.toJson(),
       );

  final Seed _seed;
  final Store _store;
  final StoredList<Pick> _picks;

  /// Turns the seed's relative picks into real ones.
  ///
  /// A seed row names a competition, a round relative to the one under way
  /// at first launch, and a fixture within it. Its choice is a side, or
  /// "right" or "wrong": the demo then opens with a pick that came in and
  /// one that did not, whatever the time is.
  static List<Pick> seedPicks(
    Seed seed,
    ScoreRepository scores,
    DateTime firstLaunch,
  ) {
    final out = <Pick>[];
    for (final j in seed.picks) {
      final f = scores.fixtureNear(
        j['competition'] as String,
        firstLaunch,
        round: j['round'] as int,
        index: j['fixture'] as int,
      );
      if (f == null) continue;
      final asked = j['choice'] as String;
      PickChoice choice;
      if (asked == 'right' || asked == 'wrong') {
        final end = scores.endOf(f.id);
        final result = end == null ? null : scores.match(f.id, end);
        if (result == null || result.stage != MatchStage.finished) continue;
        final t = result.tally;
        final winner = t.home == t.away
            ? PickChoice.draw
            : t.home > t.away
            ? PickChoice.home
            : PickChoice.away;
        choice = asked == 'right'
            ? winner
            : (winner == PickChoice.home ? PickChoice.away : PickChoice.home);
      } else {
        choice = PickChoice.values.byName(asked);
      }
      out.add(
        Pick(
          id: 'seed-${f.id}',
          fixtureId: f.id,
          choice: choice,
          madeAt: f.kickoff.subtract(const Duration(minutes: 3)),
        ),
      );
    }
    return out;
  }

  @override
  Future<UserProfile> profile() async {
    final saved = _store.json<Map<String, dynamic>>(Store.profile);
    return saved == null ? _seed.profile : UserProfile.fromJson(saved);
  }

  @override
  Future<UserProfile> updateProfile(UserProfile profile) async {
    await _store.setJson(Store.profile, profile.toJson());
    return profile;
  }

  @override
  Future<List<String>> following() async =>
      _store.strings(Store.following) ?? _seed.following;

  @override
  Future<void> setFollowing(List<String> teamIds) =>
      _store.setStrings(Store.following, teamIds);

  @override
  Future<List<Pick>> picks() async => _picks.read();

  @override
  Future<void> savePick(Pick pick, {int? at}) {
    final list = _picks.read();
    if (list.any((p) => p.id == pick.id)) {
      return _picks.write([for (final p in list) p.id == pick.id ? pick : p]);
    }
    return _picks.write(
      [...list]..insert((at ?? 0).clamp(0, list.length), pick),
    );
  }

  @override
  Future<void> deletePick(String id) => _picks.write([
    for (final p in _picks.read())
      if (p.id != id) p,
  ]);

  @override
  Future<String?> pinnedMatch() async => _store.string(Store.pinned);

  @override
  Future<void> setPinnedMatch(String? fixtureId) =>
      _store.setString(Store.pinned, fixtureId);

  @override
  Future<AlertPrefs> alertPrefs() async {
    final j = _store.json<Map<String, dynamic>>(Store.alertPrefs);
    return j == null ? const AlertPrefs() : AlertPrefs.fromJson(j);
  }

  @override
  Future<void> setAlertPrefs(AlertPrefs prefs) =>
      _store.setJson(Store.alertPrefs, prefs.toJson());

  @override
  Future<Set<String>> alertsRead() async => {
    ...?_store.strings(Store.alertsRead),
  };

  @override
  Future<void> setAlertsRead(Set<String> ids) =>
      _store.setStrings(Store.alertsRead, ids);

  @override
  Future<Set<String>> alertsCleared() async => {
    ...?_store.strings(Store.alertsCleared),
  };

  @override
  Future<void> setAlertsCleared(Set<String> ids) =>
      _store.setStrings(Store.alertsCleared, ids);

  @override
  Future<List<String>> recentSearches() async =>
      _store.strings(Store.recentSearches) ?? _seed.recentSearches;

  @override
  Future<void> setRecentSearches(List<String> terms) =>
      _store.setStrings(Store.recentSearches, terms);
}

// A network implementation. The JSON shapes match the seed files, so every
// model's fromJson is reused as it is: nothing else in the app changes.
//
// class RemoteAccountRepository implements AccountRepository {
//   RemoteAccountRepository(this._dio);
//   final Dio _dio;
//
//   @override
//   Future<UserProfile> profile() async =>
//       UserProfile.fromJson((await _dio.get('/me')).data);
//
//   @override
//   Future<void> savePick(Pick pick, {int? at}) =>
//       _dio.put('/me/picks/${pick.id}', data: pick.toJson());
//   ...
// }
