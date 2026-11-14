import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_brand.dart';
import '../../config/app_theme.dart';
import '../../config/app_timing.dart';
import '../../config/motion.dart';
import '../../providers/core_providers.dart';
import '../../widgets/ambient.dart';
import '../../widgets/floodlight_mark.dart';

/// `intro`: the splash plays over a blank page. `warming`: the first screen
/// is mounted underneath, hidden, so its heavy first build happens while the
/// wordmark holds; its entrance waits. `leaving`: the splash opens and the
/// first screen's entrance plays. `done`: the splash is gone.
enum SplashPhase { intro, warming, leaving, done }

final splashPhaseProvider = StateProvider<SplashPhase>(
  (_) => AppTiming.scale == 0 ? SplashPhase.done : SplashPhase.intro,
);

/// The opening shot: a mast rises, the lamp panel swings up onto it, and
/// six lamps come on one at a time. The name settles underneath. Then the
/// light floods: a circle opens from the lamps until it is the whole
/// screen, and the first page is what it was shining on.
///
/// One controller in, one out. It leaves only when the intro has played
/// *and* the scores have loaded, so it never opens onto a half-loaded
/// screen. With reduced motion (and in tests) it dissolves instead.
class SplashOverlay extends ConsumerStatefulWidget {
  const SplashOverlay({super.key});

  @override
  ConsumerState<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends ConsumerState<SplashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _in;
  late final AnimationController _out;
  bool _lit = false;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(vsync: this, duration: AppTiming.splashIn);
    _out = AnimationController(vsync: this, duration: AppTiming.splashOut);
    _run();
  }

  /// The scores, through their repository, and the tables added up once:
  /// with a backend this is the first network call, and the splash covers
  /// it.
  Future<void> _load() async {
    final scores = await ref.read(scoreRepositoryProvider.future);
    final now = ref.read(clockProvider)();
    for (final c in scores.competitions) {
      scores.table(c.id, now);
    }
    await ref.read(accountRepositoryProvider.future);
  }

  Future<void> _run() async {
    final ready = _load();
    _in.addListener(_light);
    await _in.forward();
    await ready;
    if (!mounted) return;
    ref.read(splashPhaseProvider.notifier).state = SplashPhase.warming;
    await AppTiming.wait(AppTiming.splashHold);
    for (var i = 0; i < 2; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    ref.read(splashPhaseProvider.notifier).state = SplashPhase.leaving;
    await _out.forward();
    if (!mounted) return;
    ref.read(splashPhaseProvider.notifier).state = SplashPhase.done;
  }

  /// A tap of haptics as the last lamp comes on.
  void _light() {
    if (!_lit && _in.value > _SplashFace.markUntil * .93) {
      _lit = true;
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flood = Motion.loops(context);
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _out]),
      builder: (context, _) => IgnorePointer(
        ignoring: _out.value > .4,
        child: flood
            ? _SplashFace(t: _in.value, leave: _out.value)
            : Opacity(
                opacity: 1 - Curves.easeInCubic.transform(_out.value),
                child: const _SplashFace(t: 1),
              ),
      ),
    );
  }
}

/// What the splash shows at [t] (0 to 1) of its way in, and at [leave]
/// (0 to 1) of the light flooding out.
class _SplashFace extends StatelessWidget {
  const _SplashFace({required this.t, this.leave = 0});

  final double t;
  final double leave;

  /// The share of the way in that the mark takes to build.
  static const markUntil = .66;
  static const _markSize = 112.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    double slice(double from, double to) =>
        ((t - from) / (to - from)).clamp(0.0, 1.0);
    final built = slice(0, markUntil);
    final word = Curves.easeOutQuart.transform(slice(.5, .92));
    final rule = Curves.easeInOutCubic.transform(slice(.62, .94));
    final tagline = Curves.easeOut.transform(slice(.78, 1));

    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final mark = Rect.fromCenter(
          center: Offset(size.width / 2, size.height * .41),
          width: _markSize,
          height: _markSize,
        );
        final focus = MarkGeometry.focus(mark);
        // Far enough to clear the furthest corner.
        final reach = math.sqrt(
          math.pow(math.max(focus.dx, size.width - focus.dx), 2) +
              math.pow(math.max(focus.dy, size.height - focus.dy), 2),
        );
        final radius = reach * Curves.easeInCubic.transform(leave);
        final fade = (1 - leave / .5).clamp(0.0, 1.0);

        // A Material, not a bare box: the splash sits above the Navigator,
        // where no Scaffold gives text a default style.
        Widget face = Material(
          color: p.paper,
          child: Stack(
            children: [
              const Positioned.fill(child: AmbientMesh()),
              Opacity(
                opacity: fade,
                child: Stack(
                  children: [
                    Positioned.fromRect(
                      rect: mark,
                      child: FloodlightMark(size: _markSize, built: built),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: mark.bottom + 22,
                      child: Column(
                        children: [
                          Opacity(
                            opacity: word,
                            child: Wordmark(size: 25, settle: word),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: 132 * rule,
                            height: 1.2,
                            color: p.accent,
                          ),
                          const SizedBox(height: 16),
                          Opacity(
                            opacity: tagline,
                            child: Transform.translate(
                              offset: Offset(0, 8 * (1 - tagline)),
                              child: Text(
                                AppBrand.tagline,
                                textAlign: TextAlign.center,
                                style: context.body.copyWith(
                                  color: p.inkSoft,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (leave > 0) {
          face = Stack(
            children: [
              ClipPath(clipper: _FloodClipper(focus, radius), child: face),
              // The edge of the light, in the accent, thinning as it grows.
              IgnorePointer(
                child: CustomPaint(
                  size: size,
                  painter: _RimPainter(
                    focus,
                    radius,
                    p.accent.withValues(alpha: .55 * (1 - leave)),
                  ),
                ),
              ),
            ],
          );
        }
        return face;
      },
    );
  }
}

/// Everything but the circle of light.
class _FloodClipper extends CustomClipper<Path> {
  const _FloodClipper(this.centre, this.radius);

  final Offset centre;
  final double radius;

  @override
  Path getClip(Size size) => Path.combine(
    PathOperation.difference,
    Path()..addRect(Offset.zero & size),
    Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
  );

  @override
  bool shouldReclip(_FloodClipper old) =>
      old.radius != radius || old.centre != centre;
}

class _RimPainter extends CustomPainter {
  const _RimPainter(this.centre, this.radius, this.color);

  final Offset centre;
  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    centre,
    radius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color,
  );

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius || old.color != color;
}

/// Starts [start] when the splash begins to leave (or at once if it already
/// has), so a first screen mounted early does not play its entrance unseen.
void startWhenRevealed(WidgetRef ref, VoidCallback start) {
  final phase = ref.read(splashPhaseProvider);
  if (phase == SplashPhase.leaving || phase == SplashPhase.done) {
    start();
    return;
  }
  late final ProviderSubscription<SplashPhase> sub;
  sub = ref.listenManual(splashPhaseProvider, (_, next) {
    if (next == SplashPhase.leaving || next == SplashPhase.done) {
      sub.close();
      start();
    }
  });
}
