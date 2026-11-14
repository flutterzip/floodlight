import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/basketball.dart';
import '../../models/league.dart';
import '../../models/match.dart';
import '../../widgets/crest.dart';
import '../../widgets/panel.dart';
import '../../widgets/rolling_number.dart';

/// The score quarter by quarter, with the running total.
class QuartersPanel extends StatelessWidget {
  const QuartersPanel(this.match, {super.key});

  final BasketballSnapshot match;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = match;
    final columns = math.max(m.byPeriod.length, BasketballSnapshot.regulation);
    final head = context.caption.copyWith(fontSize: 11.5);
    final cell = context.figure.copyWith(fontSize: 13.5);

    Widget row(Side? side) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: side == null
                ? const SizedBox.shrink()
                : Row(
                    children: [
                      CrestBadge(m.team(side), size: 20),
                      const SizedBox(width: Space.sm),
                      Flexible(
                        child: Text(
                          m.team(side).short,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.title.copyWith(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
          ),
          for (var q = 0; q < columns; q++)
            SizedBox(
              width: 36,
              child: Align(
                alignment: Alignment.centerRight,
                child: side == null
                    ? Text(BasketballSnapshot.periodName(q + 1), style: head)
                    : q < m.byPeriod.length
                    ? RollingNumber(
                        '${side == Side.home ? m.byPeriod[q].$1 : m.byPeriod[q].$2}',
                        highlight: p.accentInk,
                        style: cell.copyWith(
                          color: q == m.period - 1 && m.stage.inPlay
                              ? p.ink
                              : p.inkSoft,
                        ),
                      )
                    : Text('-', style: cell.copyWith(color: p.muted)),
              ),
            ),
          SizedBox(
            width: 46,
            child: Align(
              alignment: Alignment.centerRight,
              child: side == null
                  ? Text('T', style: head)
                  : RollingNumber(
                      '${m.points(side)}',
                      highlight: p.accentInk,
                      style: cell.copyWith(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );

    return Panel(
      key: const Key('quarters-panel'),
      title: 'By quarter',
      child: Column(
        children: [
          row(null),
          Divider(color: p.line),
          row(Side.home),
          row(Side.away),
        ],
      ),
    );
  }
}

/// The margin through the game: above the line when the home side leads,
/// below it when the away side does.
class LeadPanel extends StatelessWidget {
  const LeadPanel(this.match, {super.key});

  final BasketballSnapshot match;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = match;
    final (bigHome, bigAway) = m.biggestLead;
    Widget figure(String label, String value) => Expanded(
      child: Figure(
        label: label,
        value: RollingNumber(
          value,
          alignment: Alignment.centerLeft,
          highlight: p.accentInk,
          style: context.figure.copyWith(fontSize: 17),
        ),
      ),
    );
    return Panel(
      key: const Key('lead-panel'),
      title: 'Lead tracker',
      child: Column(
        children: [
          Semantics(
            label:
                'Lead through the game. ${m.home.name} above the line, '
                '${m.away.name} below.',
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(double.infinity, 110),
                painter: _LeadPainter(
                  points: m.lead,
                  progress: m.progress,
                  periods: m.periods,
                  home: p.tint(m.home.crest.tint),
                  away: p.tint(m.away.crest.tint),
                  line: p.line,
                  now: p.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              figure('Lead changes', '${m.leadChanges}'),
              figure('${m.home.short} biggest', '$bigHome'),
              figure('${m.away.short} biggest', '$bigAway'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeadPainter extends CustomPainter {
  const _LeadPainter({
    required this.points,
    required this.progress,
    required this.periods,
    required this.home,
    required this.away,
    required this.line,
    required this.now,
  });

  final List<LeadPoint> points;
  final double progress;
  final int periods;
  final Color home;
  final Color away;
  final Color line;
  final Color now;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    var most = 8;
    for (final pt in points) {
      most = math.max(most, pt.margin.abs());
    }
    final scale = (mid - 6) / most;
    final rule = Paint()
      ..color = line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, mid), Offset(size.width, mid), rule);
    for (var q = 1; q < BasketballSnapshot.regulation; q++) {
      // Overtime is short; the quarter marks are close enough as fractions
      // of regulation for a guide line.
      final x =
          size.width * q / math.max(periods, BasketballSnapshot.regulation);
      canvas.drawLine(Offset(x, 4), Offset(x, size.height - 4), rule);
    }
    if (points.length < 2) return;

    // A stepped line: the margin holds until somebody scores.
    final path = Path()..moveTo(0, mid);
    var y = mid;
    for (final pt in points) {
      final x = size.width * pt.at;
      path.lineTo(x, y);
      y = mid - pt.margin * scale;
      path.lineTo(x, y);
    }
    final end = size.width * progress;
    path.lineTo(end, y);
    final area = Path.from(path)
      ..lineTo(end, mid)
      ..close();

    // Fill each half in its side's colour by clipping the same area twice.
    for (final (clip, color) in [
      (Rect.fromLTRB(0, 0, size.width, mid), home),
      (Rect.fromLTRB(0, mid, size.width, size.height), away),
    ]) {
      canvas
        ..save()
        ..clipRect(clip)
        ..drawPath(area, Paint()..color = color.withValues(alpha: .28))
        ..drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeJoin = StrokeJoin.round,
        )
        ..restore();
    }
    if (progress < 1) {
      canvas.drawCircle(Offset(end, y), 3.6, Paint()..color = now);
    }
  }

  @override
  bool shouldRepaint(_LeadPainter old) =>
      old.points.length != points.length ||
      old.progress != progress ||
      old.home != home ||
      old.away != away ||
      old.line != line;
}

/// Every player's line, starters first, for one side at a time.
class BoxScoreView extends StatefulWidget {
  const BoxScoreView(this.match, {super.key});

  final BasketballSnapshot match;

  @override
  State<BoxScoreView> createState() => _BoxScoreViewState();
}

class _BoxScoreViewState extends State<BoxScoreView> {
  Side _side = Side.home;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = widget.match;
    final lines = m.box(_side);
    final head = context.caption.copyWith(fontSize: 11.5);
    final cell = context.figure.copyWith(fontSize: 13.5, color: p.inkSoft);
    const widths = [38.0, 38.0, 38.0, 52.0, 34.0];

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

    Widget line(BoxLine l) => Padding(
      key: Key('box-${l.player.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: l.onCourt
                ? Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Text(
              l.player.shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.title.copyWith(
                fontSize: 14,
                fontWeight: l.starter ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          cells([
            RollingNumber(
              '${l.points}',
              highlight: p.accentInk,
              style: cell.copyWith(color: p.ink, fontWeight: FontWeight.w700),
            ),
            RollingNumber('${l.rebounds}', highlight: p.accentInk, style: cell),
            RollingNumber('${l.assists}', highlight: p.accentInk, style: cell),
            Text('${l.made}-${l.attempts}', style: cell),
            Text('${l.threes}', style: cell),
          ]),
        ],
      ),
    );

    int sum(int Function(BoxLine) of) => lines.fold(0, (s, l) => s + of(l));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.md,
          ),
          child: SideSwitch(
            match: m,
            side: _side,
            onChanged: (s) => setState(() => _side = s),
          ),
        ),
        Panel(
          key: const Key('box-score'),
          padding: const EdgeInsets.fromLTRB(
            Space.md,
            Space.md,
            Space.lg,
            Space.md,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(child: Text('Player', style: head)),
                  cells([
                    for (final h in ['PTS', 'REB', 'AST', 'FG', '3P'])
                      Text(h, style: head),
                  ]),
                ],
              ),
              const SizedBox(height: 4),
              Divider(color: p.line),
              for (var i = 0; i < lines.length; i++) ...[
                if (i == 5) ...[
                  Divider(color: p.line),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 8),
                      child: Text(
                        'BENCH',
                        style: context.label.copyWith(color: p.muted),
                      ),
                    ),
                  ),
                ],
                line(lines[i]),
              ],
              Divider(color: p.line),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Team',
                        style: context.title.copyWith(fontSize: 14),
                      ),
                    ),
                    cells([
                      Text(
                        '${sum((l) => l.points)}',
                        style: cell.copyWith(
                          color: p.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('${sum((l) => l.rebounds)}', style: cell),
                      Text('${sum((l) => l.assists)}', style: cell),
                      Text(
                        '${sum((l) => l.made)}-${sum((l) => l.attempts)}',
                        style: cell,
                      ),
                      Text('${sum((l) => l.threes)}', style: cell),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Chooses which side a table shows, by crest and name. Shared with the
/// cricket scorecard.
class SideSwitch extends StatelessWidget {
  const SideSwitch({
    super.key,
    required this.match,
    required this.side,
    required this.onChanged,
  });

  final MatchSnapshot match;
  final Side side;
  final ValueChanged<Side> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        for (final s in Side.values) ...[
          if (s == Side.away) const SizedBox(width: Space.sm),
          Expanded(
            child: Semantics(
              button: true,
              selected: s == side,
              label: match.team(s).name,
              excludeSemantics: true,
              child: GestureDetector(
                key: Key('side-${s.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: Space.md),
                  decoration: BoxDecoration(
                    color: s == side ? p.card : p.field,
                    borderRadius: BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: s == side ? p.ink : p.field,
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CrestBadge(match.team(s), size: 20),
                      const SizedBox(width: Space.sm),
                      Flexible(
                        child: Text(
                          match.team(s).name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.title.copyWith(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
