import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// Where the pieces of the logo sit on a unit square. Shared with
/// `tool/make_mark.py`, which draws the app icon from the same numbers:
/// keep the two in step.
abstract final class MarkGeometry {
  /// The lamp panel: its centre, size, corner radius and tilt.
  static const panelCentre = Offset(.5, .37);
  static const panelSize = Size(.7, .44);
  static const panelRadius = .09;
  static const tilt = -8 * math.pi / 180;

  /// Six lamps, three across and two down, within the panel.
  static const lampRadius = .068;
  static const lampGapX = .2;
  static const lampGapY = .19;

  /// The mast, from under the panel to the ground.
  static const mastTop = .58;
  static const mastFoot = .93;
  static const mastWidth = .07;
  static const footWidth = .3;

  static List<Offset> get lamps => [
    for (var row = 0; row < 2; row++)
      for (var col = 0; col < 3; col++)
        Offset((col - 1) * lampGapX, (row - .5) * lampGapY),
  ];

  /// The middle of the lamps, in the coordinates of [rect].
  static Offset focus(Rect rect) => Offset(
    rect.left + rect.width * panelCentre.dx,
    rect.top + rect.height * panelCentre.dy,
  );
}

/// The Floodlight mark: a bank of six lamps on a mast.
///
/// [built] runs 0 to 1 and assembles it: the mast rises, the panel swings
/// up onto it, then the lamps come on one at a time. At rest all six are
/// lit.
class FloodlightMark extends StatelessWidget {
  const FloodlightMark({
    super.key,
    this.size = 48,
    this.built = 1,
    this.body,
    this.lamp,
    this.glow = true,
  });

  final double size;
  final double built;

  /// Defaults to the ink and the accent.
  final Color? body;
  final Color? lamp;
  final bool glow;

  /// When, on the way to built, the last lamp comes on.
  static const lampsFrom = .46;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(
        built: built,
        body: body ?? p.ink,
        lamp: lamp ?? p.accent,
        dark: p.paper,
        glow: glow,
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.built,
    required this.body,
    required this.lamp,
    required this.dark,
    required this.glow,
  });

  final double built;
  final Color body;
  final Color lamp;

  /// A lamp that is not lit yet: the ground showing through.
  final Color dark;
  final bool glow;

  double _slice(double from, double to) =>
      ((built - from) / (to - from)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final ink = Paint()..color = body;
    final mast = Curves.easeOutCubic.transform(_slice(0, .22));
    final panel = Curves.easeOutBack.transform(_slice(.14, .44));

    // The mast and its foot.
    final footY = s * MarkGeometry.mastFoot;
    final top = footY - (footY - s * MarkGeometry.mastTop) * mast;
    if (mast > 0) {
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              s * (.5 - MarkGeometry.mastWidth / 2),
              top,
              s * (.5 + MarkGeometry.mastWidth / 2),
              footY,
            ),
            Radius.circular(s * .02),
          ),
          ink,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(s * .5, footY),
              width: s * MarkGeometry.footWidth * mast,
              height: s * .06,
            ),
            Radius.circular(s * .03),
          ),
          ink,
        );
    }
    if (panel <= 0) return;

    final centre = Offset(
      s * MarkGeometry.panelCentre.dx,
      s * MarkGeometry.panelCentre.dy,
    );
    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      // It swings up from flat as it lands.
      ..rotate(MarkGeometry.tilt * panel)
      ..scale(panel);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: s * MarkGeometry.panelSize.width,
      height: s * MarkGeometry.panelSize.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect,
        Radius.circular(s * MarkGeometry.panelRadius),
      ),
      ink,
    );
    final lamps = MarkGeometry.lamps;
    for (var i = 0; i < lamps.length; i++) {
      final from = FloodlightMark.lampsFrom + i * .075;
      final on = Curves.easeOut.transform(_slice(from, from + .1));
      final at = lamps[i] * s;
      final r = s * MarkGeometry.lampRadius;
      if (glow && on > 0) {
        canvas.drawCircle(
          at,
          r * 2.1,
          Paint()
            ..color = lamp.withValues(alpha: .28 * on)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .9),
        );
      }
      canvas.drawCircle(
        at,
        r,
        Paint()..color = Color.lerp(dark.withValues(alpha: .22), lamp, on)!,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.built != built ||
      old.body != body ||
      old.lamp != lamp ||
      old.dark != dark;
}
