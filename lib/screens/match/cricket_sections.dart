import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/cricket.dart';
import '../../widgets/panel.dart';
import '../../widgets/rolling_number.dart';

/// The middle: who is batting and bowling right now, the over as it is
/// bowled, and the rates. Every figure here can change on one ball, and
/// each rolls on its own.
class CreasePanel extends StatelessWidget {
  const CreasePanel(this.match, {super.key});

  final CricketSnapshot match;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = match;
    final innings = m.current;
    if (innings == null) return const SizedBox.shrink();
    final batting = [
      for (final b in innings.batters)
        if (b.state == BatterState.batting) b,
    ];
    final bowler = innings.bowlers.where((b) => b.bowling).firstOrNull;
    final head = context.caption.copyWith(fontSize: 11.5);
    final cell = context.figure.copyWith(fontSize: 13.5, color: p.inkSoft);
    const widths = [34.0, 34.0, 28.0, 28.0, 50.0];

    Widget cells(List<Widget> values) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < values.length; i++)
          SizedBox(
            width: widths[i],
            child: Align(alignment: Alignment.centerRight, child: values[i]),
          ),
      ],
    );
    Widget roll(String v, {bool strong = false}) => RollingNumber(
      v,
      highlight: p.accentInk,
      style: strong
          ? cell.copyWith(color: p.ink, fontWeight: FontWeight.w800)
          : cell,
    );

    final need = m.needed;
    final required = m.requiredRate;
    return Panel(
      key: const Key('crease-panel'),
      title: innings.closed ? 'End of innings' : 'In the middle',
      trailing: Text(
        '${m.team(innings.batting).short} ${innings.total}',
        style: context.figure.copyWith(fontSize: 12, color: p.muted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!innings.closed) ...[
            Row(
              children: [
                Expanded(child: Text('Batting', style: head)),
                cells([
                  for (final h in ['R', 'B', '4s', '6s', 'SR'])
                    Text(h, style: head),
                ]),
              ],
            ),
            for (final b in batting)
              Padding(
                key: Key('batting-${b.player.id}'),
                padding: const EdgeInsets.only(top: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${b.player.shortName}${b.onStrike ? ' *' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.title.copyWith(fontSize: 14),
                      ),
                    ),
                    cells([
                      roll('${b.runs}', strong: true),
                      roll('${b.balls}'),
                      roll('${b.fours}'),
                      roll('${b.sixes}'),
                      roll(b.strikeRate.toStringAsFixed(1)),
                    ]),
                  ],
                ),
              ),
            const SizedBox(height: Space.md),
            Divider(color: p.line),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(child: Text('Bowling', style: head)),
                cells([
                  for (final h in ['O', 'M', 'R', 'W', 'Econ'])
                    Text(h, style: head),
                ]),
              ],
            ),
            if (bowler != null)
              Padding(
                padding: const EdgeInsets.only(top: 9),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        bowler.player.shortName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.title.copyWith(fontSize: 14),
                      ),
                    ),
                    cells([
                      roll(bowler.overs),
                      roll('${bowler.maidens}'),
                      roll('${bowler.runs}'),
                      roll('${bowler.wickets}', strong: true),
                      roll(bowler.economy.toStringAsFixed(1)),
                    ]),
                  ],
                ),
              ),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                Text('This over', style: head),
                const SizedBox(width: Space.md),
                Expanded(child: OverStrip(m.thisOver)),
              ],
            ),
            const SizedBox(height: Space.lg),
          ],
          Row(
            children: [
              Expanded(
                child: Figure(
                  label: 'Run rate',
                  value: RollingNumber(
                    innings.runRate.toStringAsFixed(2),
                    alignment: Alignment.centerLeft,
                    highlight: p.accentInk,
                    style: context.figure.copyWith(fontSize: 17),
                  ),
                ),
              ),
              if (required != null && need != null && !innings.closed)
                Expanded(
                  child: Figure(
                    label: 'Required rate',
                    value: RollingNumber(
                      required.toStringAsFixed(2),
                      alignment: Alignment.centerLeft,
                      highlight: p.accentInk,
                      style: context.figure.copyWith(
                        fontSize: 17,
                        // Behind the rate reads in the accent; ahead is calm.
                        color: required > innings.runRate ? p.accentInk : p.ink,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Figure(
                    label: 'Projected',
                    value: RollingNumber(
                      '${(innings.runRate * CricketSnapshot.oversPerSide).round()}',
                      alignment: Alignment.centerLeft,
                      highlight: p.accentInk,
                      style: context.figure.copyWith(fontSize: 17),
                    ),
                  ),
                ),
              Expanded(
                child: Figure(
                  label: 'Partnership',
                  value: RollingNumber(
                    '${m.partnership.$1} (${m.partnership.$2})',
                    alignment: Alignment.centerLeft,
                    highlight: p.accentInk,
                    style: context.figure.copyWith(fontSize: 17),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The balls of the over so far, each in its own disc: a boundary filled
/// with the accent, a wicket in ink, a dot quiet.
class OverStrip extends StatelessWidget {
  const OverStrip(this.balls, {super.key});

  final List<BallMark> balls;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: balls.isEmpty
          ? 'No balls bowled in this over yet'
          : 'This over: ${balls.map((b) => b.text == '•' ? 'dot' : b.text).join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        height: 30,
        child: ListView.separated(
          key: const Key('over-strip'),
          scrollDirection: Axis.horizontal,
          itemCount: balls.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final b = balls[i];
            final (fill, ink) = b.wicket
                ? (p.ink, p.paper)
                : b.boundary
                ? (p.accent, p.onAccent)
                : b.extra
                ? (p.accentWash, p.accentInk)
                : (p.field, p.inkSoft);
            // The newest ball pops in.
            return TweenAnimationBuilder<double>(
              key: ValueKey(i),
              tween: Tween(begin: i == balls.length - 1 ? .4 : 1, end: 1),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              builder: (_, s, child) => Transform.scale(scale: s, child: child),
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                child: Text(
                  b.text,
                  style: TextStyle(
                    color: ink,
                    fontSize: b.text.length > 1 ? 10.5 : 12.5,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Both innings as lines of runs against overs, so a chase can be read
/// against what it is chasing.
class WormPanel extends StatelessWidget {
  const WormPanel(this.match, {super.key});

  final CricketSnapshot match;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = match;
    if (m.innings.isEmpty) return const SizedBox.shrink();
    return Panel(
      key: const Key('worm-panel'),
      title: 'Run chase',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Runs by over for each innings',
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(double.infinity, 120),
                painter: _WormPainter(
                  lines: [
                    for (final i in m.innings)
                      (
                        [0, ...i.byOver],
                        p.tint(m.team(i.batting).crest.tint),
                        i.balls,
                      ),
                  ],
                  grid: p.line,
                  label: context.caption.copyWith(fontSize: 10),
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.lg,
            children: [
              for (final i in m.innings)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 3,
                      color: p.tint(m.team(i.batting).crest.tint),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${m.team(i.batting).short} ${i.total} (${i.overs})',
                      style: context.caption.copyWith(
                        fontSize: 11.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WormPainter extends CustomPainter {
  const _WormPainter({
    required this.lines,
    required this.grid,
    required this.label,
  });

  /// The total after each over (from zero), its colour, and balls bowled.
  final List<(List<int>, Color, int)> lines;
  final Color grid;
  final TextStyle label;

  @override
  void paint(Canvas canvas, Size size) {
    var top = 120;
    for (final (totals, _, _) in lines) {
      top = math.max(top, totals.last);
    }
    top = ((top + 39) ~/ 40) * 40;
    const left = 26.0;
    final w = size.width - left, h = size.height - 4;
    final rule = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var v = 0; v <= top; v += top ~/ 4) {
      final y = h - h * v / top;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), rule);
      final tp = TextPainter(
        text: TextSpan(text: '$v', style: label),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(left - tp.width - 6, y - tp.height / 2));
      tp.dispose();
    }
    for (final (totals, color, balls) in lines) {
      if (totals.length < 2) continue;
      final path = Path()..moveTo(left, h);
      Offset end = Offset(left, h);
      for (var o = 1; o < totals.length; o++) {
        // The last point sits at the ball it was bowled, not the over end.
        final overs = o == totals.length - 1 ? balls / 6 : o.toDouble();
        end = Offset(
          left + w * overs / CricketSnapshot.oversPerSide,
          h - h * totals[o] / top,
        );
        path.lineTo(end.dx, end.dy);
      }
      canvas
        ..drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        )
        ..drawCircle(end, 3.4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_WormPainter old) {
    if (old.lines.length != lines.length || old.grid != grid) return true;
    for (var i = 0; i < lines.length; i++) {
      if (old.lines[i].$3 != lines[i].$3 ||
          old.lines[i].$1.last != lines[i].$1.last ||
          old.lines[i].$2 != lines[i].$2) {
        return true;
      }
    }
    return false;
  }
}
