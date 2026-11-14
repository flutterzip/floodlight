import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/motion.dart';

/// The red light beside anything live. It breathes while motion is on and
/// sits still when it is not.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 7, this.color});

  final double size;
  final Color? color;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only loops when motion is wanted. The ticker itself is muted by the
    // framework while its route or tab is hidden.
    final run = Motion.loops(context);
    if (run && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!run && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.palette.accent;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size * 2.4),
        painter: _DotPainter(_pulse, color, widget.size / 2),
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.pulse, this.color, this.radius) : super(repaint: pulse);

  final Animation<double> pulse;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final t = pulse.value;
    if (t > 0) {
      canvas.drawCircle(
        c,
        radius * (1 + 1.4 * Curves.easeOut.transform(t)),
        Paint()..color = color.withValues(alpha: .35 * (1 - t)),
      );
    }
    canvas.drawCircle(c, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.color != color || old.radius != radius;
}

/// "LIVE", with its light.
class LiveTag extends StatelessWidget {
  const LiveTag({super.key, this.label = 'LIVE', this.onBoard = false});

  final String label;

  /// On the dark scoreboard, where the ink is light in both modes.
  final bool onBoard;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const LiveDot(size: 6),
        const SizedBox(width: 2),
        Text(
          label,
          style: context.label.copyWith(
            color: onBoard ? p.onBoard : p.accentInk,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// A bar that grows to [value] (0 to 1) whenever it changes.
class GrowBar extends StatelessWidget {
  const GrowBar({
    super.key,
    required this.value,
    required this.color,
    this.track,
    this.height = 6,
    this.fromRight = false,
  });

  final double value;
  final Color color;
  final Color? track;
  final double height;
  final bool fromRight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: track ?? p.plate,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0.0, 1.0)),
            duration: Motion.reduced(context) ? Duration.zero : Motion.grow,
            curve: Motion.settle,
            builder: (_, v, _) => FractionallySizedBox(
              alignment: fromRight
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              widthFactor: v,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
