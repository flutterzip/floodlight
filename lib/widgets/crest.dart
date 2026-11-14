import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/league.dart';

/// A team's crest: a shield in the team's tint with its pattern cut into
/// it. Drawn in code from two values in the seed, so a new team needs no
/// artwork.
class CrestBadge extends StatelessWidget {
  const CrestBadge(this.team, {super.key, this.size = 36});

  final Team team;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '${team.name} crest',
      image: true,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _CrestPainter(
            pattern: team.crest.pattern,
            tint: p.tint(team.crest.tint),
            mark: p.onTeam,
          ),
        ),
      ),
    );
  }
}

class _CrestPainter extends CustomPainter {
  const _CrestPainter({
    required this.pattern,
    required this.tint,
    required this.mark,
  });

  final CrestPattern pattern;
  final Color tint;
  final Color mark;

  static Path shield(Size s) {
    final w = s.width, h = s.height;
    return Path()
      ..moveTo(w * .2, h * .07)
      ..lineTo(w * .8, h * .07)
      ..quadraticBezierTo(w * .9, h * .07, w * .9, h * .17)
      ..lineTo(w * .9, h * .5)
      ..cubicTo(w * .9, h * .76, w * .68, h * .9, w * .5, h * .97)
      ..cubicTo(w * .32, h * .9, w * .1, h * .76, w * .1, h * .5)
      ..lineTo(w * .1, h * .17)
      ..quadraticBezierTo(w * .1, h * .07, w * .2, h * .07)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final outline = shield(size);
    canvas
      ..drawPath(outline, Paint()..color = tint)
      ..save()
      ..clipPath(outline);
    final fill = Paint()..color = mark.withValues(alpha: .94);
    Rect box(double l, double t, double r, double b) =>
        Rect.fromLTRB(w * l, h * t, w * r, h * b);
    switch (pattern) {
      case CrestPattern.plain:
        canvas.drawCircle(Offset(w * .5, h * .44), w * .15, fill);
      case CrestPattern.stripes:
        for (final x in [.26, .5, .74]) {
          canvas.drawRect(box(x - .065, 0, x + .065, 1), fill);
        }
      case CrestPattern.hoops:
        for (final y in [.22, .46, .7]) {
          canvas.drawRect(box(0, y - .06, 1, y + .06), fill);
        }
      case CrestPattern.sash:
        canvas.drawPath(
          Path()
            ..moveTo(w * .1, h * .2)
            ..lineTo(w * .32, h * .07)
            ..lineTo(w * .9, h * .62)
            ..lineTo(w * .74, h * .82)
            ..close(),
          fill,
        );
      case CrestPattern.halves:
        canvas.drawRect(box(.5, 0, 1, 1), fill);
      case CrestPattern.chevron:
        canvas.drawPath(
          Path()
            ..moveTo(w * .1, h * .3)
            ..lineTo(w * .5, h * .58)
            ..lineTo(w * .9, h * .3)
            ..lineTo(w * .9, h * .5)
            ..lineTo(w * .5, h * .78)
            ..lineTo(w * .1, h * .5)
            ..close(),
          fill,
        );
      case CrestPattern.quarters:
        canvas
          ..drawRect(box(0, 0, .5, .48), fill)
          ..drawRect(box(.5, .48, 1, 1), fill);
      case CrestPattern.band:
        canvas.drawRect(box(0, .34, 1, .56), fill);
    }
    canvas
      ..restore()
      ..drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (w * .045).clamp(1.0, 2.4)
          ..color = tint,
      );
  }

  @override
  bool shouldRepaint(_CrestPainter old) =>
      old.pattern != pattern || old.tint != tint || old.mark != mark;
}
