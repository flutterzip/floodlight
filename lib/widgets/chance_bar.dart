import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/motion.dart';
import '../models/format.dart';
import '../models/league.dart';
import '../models/match.dart';

/// Who is likely to win, as one bar split between the two crest colours
/// with a quiet middle for the draw. The split slides when it changes.
class ChanceBar extends StatelessWidget {
  const ChanceBar({
    super.key,
    required this.chance,
    required this.home,
    required this.away,
    this.height = 6,
    this.labels = false,
    this.onBoard = false,
  });

  final WinChance chance;
  final Team home;
  final Team away;
  final double height;

  /// Percentages under the bar.
  final bool labels;
  final bool onBoard;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final quiet = onBoard ? p.boardLine : p.plate;
    final ink = onBoard ? p.onBoard : p.ink;
    final soft = onBoard ? p.boardMuted : p.muted;
    final bar = TweenAnimationBuilder<Offset>(
      // dx is where the home part ends, dy where the away part starts.
      tween: Tween(end: Offset(chance.home, chance.home + chance.draw)),
      duration: Motion.reduced(context) ? Duration.zero : Motion.long,
      curve: Motion.settle,
      builder: (_, v, _) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _ChancePainter(
          split: v,
          home: p.tint(home.crest.tint),
          away: p.tint(away.crest.tint),
          draw: quiet,
          gap: onBoard ? p.board : p.card,
        ),
      ),
    );
    if (!labels) return bar;
    final figures = context.figure.copyWith(fontSize: 12.5, color: ink);
    return Semantics(
      label:
          'Win chance: ${home.name} ${percent(chance.home)}, '
          '${chance.draw > 0 ? 'draw ${percent(chance.draw)}, ' : ''}'
          '${away.name} ${percent(chance.away)}',
      excludeSemantics: true,
      child: Column(
        children: [
          bar,
          const SizedBox(height: 7),
          Row(
            children: [
              Text(percent(chance.home), style: figures),
              const SizedBox(width: 5),
              Text(home.short, style: context.caption.copyWith(color: soft)),
              Expanded(
                child: chance.draw > 0
                    ? Text(
                        'Draw ${percent(chance.draw)}',
                        textAlign: TextAlign.center,
                        style: context.caption.copyWith(
                          color: soft,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Text(away.short, style: context.caption.copyWith(color: soft)),
              const SizedBox(width: 5),
              Text(percent(chance.away), style: figures),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChancePainter extends CustomPainter {
  const _ChancePainter({
    required this.split,
    required this.home,
    required this.away,
    required this.draw,
    required this.gap,
  });

  final Offset split;
  final Color home;
  final Color away;
  final Color draw;
  final Color gap;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final all = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas
      ..save()
      ..clipRRect(all)
      ..drawRect(Offset.zero & size, Paint()..color = draw);
    final a = size.width * split.dx.clamp(0.0, 1.0);
    final b = size.width * split.dy.clamp(0.0, 1.0);
    canvas
      ..drawRect(Rect.fromLTRB(0, 0, a, size.height), Paint()..color = home)
      ..drawRect(
        Rect.fromLTRB(b, 0, size.width, size.height),
        Paint()..color = away,
      );
    // A hair of ground between the parts, so two dark tints still read as
    // two.
    final cut = Paint()
      ..color = gap
      ..strokeWidth = 2;
    for (final x in {a, b}) {
      if (x > 1 && x < size.width - 1) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), cut);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChancePainter old) =>
      old.split != split ||
      old.home != home ||
      old.away != away ||
      old.draw != draw;
}
