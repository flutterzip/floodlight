/// A small deterministic generator (xorshift32). The same seed always gives
/// the same match, on every device and in every test, which is what lets a
/// match be worked out from the clock instead of being stored.
class Rng {
  Rng(int seed)
    : _s = (seed & 0x7FFFFFFF) == 0 ? 0x2545F491 : seed & 0x7FFFFFFF {
    for (var i = 0; i < 8; i++) {
      _next();
    }
  }

  factory Rng.of(String key) => Rng(hashOf(key));

  int _s;

  int _next() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    return _s = x & 0xFFFFFFFF;
  }

  /// 0 up to, not including, 1.
  double d() => _next() / 0x100000000;

  /// 0 up to, not including, [n].
  int i(int n) => (d() * n).floor();

  bool chance(double p) => d() < p;

  T pick<T>(List<T> items) => items[i(items.length)];

  /// One of [items], each as likely as its weight is heavy.
  T weighted<T>(List<T> items, double Function(T) weight) {
    var total = 0.0;
    for (final it in items) {
      total += weight(it);
    }
    var at = d() * total;
    for (final it in items) {
      at -= weight(it);
      if (at < 0) return it;
    }
    return items.last;
  }
}

/// FNV-1a, 32 bit. Stable across platforms, unlike `String.hashCode`.
int hashOf(String key) {
  var h = 0x811C9DC5;
  for (final c in key.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}
