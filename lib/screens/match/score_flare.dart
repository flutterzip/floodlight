import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_theme.dart';
import '../../config/motion.dart';
import '../../models/league.dart';
import '../../models/match.dart';

/// The lamps flare when somebody scores: a burst of light behind the
/// numbers and a tap of haptics. Nothing under reduce motion.
class ScoreFlare extends StatefulWidget {
  const ScoreFlare(this.match, {super.key});

  final MatchSnapshot match;

  @override
  State<ScoreFlare> createState() => _ScoreFlareState();
}

class _ScoreFlareState extends State<ScoreFlare>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst;

  @override
  void initState() {
    super.initState();
    _burst = AnimationController(vsync: this, duration: Motion.celebrate);
  }

  @override
  void didUpdateWidget(ScoreFlare old) {
    super.didUpdateWidget(old);
    final was = old.match, now = widget.match;
    // Basketball scores every few seconds: a flare each time would never
    // stop. It keeps its rolling numbers and nothing more.
    if (now.sport == Sport.basketball || was.id != now.id) return;
    if (now.scoringMoments > was.scoringMoments &&
        now.stage.inPlay &&
        !Motion.reduced(context)) {
      HapticFeedback.mediumImpact();
      _burst.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _FlarePainter(_burst, context.palette.accent),
      ),
    ),
  );
}

class _FlarePainter extends CustomPainter {
  _FlarePainter(this.burst, this.color) : super(repaint: burst);

  final Animation<double> burst;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final t = burst.value;
    if (t <= 0 || t >= 1) return;
    final c = Offset(size.width / 2, size.height * .32);
    final fade = math.pow(1 - t, 1.5).toDouble();
    final reach = size.width * (.18 + .5 * Curves.easeOutCubic.transform(t));
    canvas.drawCircle(
      c,
      reach,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: .5 * fade),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: reach)),
    );
    // Six rays, one for each lamp.
    final ray = Paint()
      ..color = color.withValues(alpha: .55 * fade)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + (i - 2.5) * .42;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * reach * .55, c + dir * reach * .9, ray);
    }
  }

  @override
  bool shouldRepaint(_FlarePainter old) => old.color != color;
}
