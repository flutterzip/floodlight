import '../models/fixture.dart';
import '../models/league.dart';
import '../models/match.dart';

/// A whole match, decided in advance from its fixture id.
///
/// An engine plays the match once into a list of timed steps. A snapshot is
/// the first N steps folded together, so the same fixture at the same
/// moment is the same scoreboard everywhere: in a list row, on the match
/// page, in the table and in a test.
abstract class MatchScript<S extends MatchSnapshot> {
  MatchScript(this.fixture, this.home, this.away);

  final Fixture fixture;
  final Team home;
  final Team away;

  Team team(Side side) => side == Side.home ? home : away;

  /// When each step happens, in real time from the start. Ascending.
  List<Duration> get offsets;

  /// From the first whistle to the last.
  Duration get length => offsets.isEmpty ? Duration.zero : offsets.last;

  /// The match after its first [count] steps.
  S build(int count, MatchStage stage);

  /// The running clock at [elapsed]: "67'", "Q3 4:12", "14.3 ov".
  String clockAt(Duration elapsed);

  /// Whether play is stopped for a break at [elapsed].
  bool pausedAt(Duration elapsed);

  int _lastCount = -1;
  MatchStage? _lastStage;
  S? _last;

  /// How many steps have happened by [elapsed].
  int stepsBy(Duration elapsed) {
    // Binary search for the first offset after [elapsed].
    var lo = 0, hi = offsets.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (offsets[mid] <= elapsed) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  MatchStage stageAt(Duration elapsed) {
    if (elapsed.isNegative) return MatchStage.upcoming;
    if (elapsed >= length) return MatchStage.finished;
    return pausedAt(elapsed) ? MatchStage.paused : MatchStage.live;
  }

  /// The match [elapsed] after its start. Returns the identical object
  /// until something new has happened, so listeners are not woken for
  /// nothing.
  S at(Duration elapsed) {
    final stage = stageAt(elapsed);
    final count = switch (stage) {
      MatchStage.upcoming => 0,
      MatchStage.finished => offsets.length,
      _ => stepsBy(elapsed),
    };
    if (count == _lastCount && stage == _lastStage) return _last!;
    _lastCount = count;
    _lastStage = stage;
    return _last = build(count, stage);
  }

  S get finalState => at(length);
}

/// Real time for a stretch of game time.
Duration realTime(double seconds) =>
    Duration(microseconds: (seconds * 1e6).round());
