import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/palette.dart';
import '../../models/football.dart';
import '../../models/league.dart';
import '../../widgets/panel.dart';

/// Who scored and when, each side on its own half of the card.
class GoalsPanel extends StatelessWidget {
  const GoalsPanel(this.match, {super.key});

  final FootballSnapshot match;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final goals = match.goalEvents.toList();
    if (goals.isEmpty) return const SizedBox.shrink();
    // One line per scorer: "Adeyemi 23', 67'".
    List<String> lines(Side side) {
      final by = <String, List<String>>{};
      for (final g in goals.where((g) => g.side == side)) {
        (by[g.playerId] ??= []).add(g.clock);
      }
      return [
        for (final e in by.entries)
          '${match.team(side).player(e.key)?.surname ?? ''} '
              '${e.value.join(', ')}',
      ];
    }

    Widget column(Side side) => Expanded(
      child: Column(
        crossAxisAlignment: side == Side.home
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        children: [
          for (final line in lines(side))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line,
                textAlign: side == Side.home ? TextAlign.left : TextAlign.right,
                style: context.body.copyWith(
                  color: p.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
    );

    return Panel(
      key: const Key('goals-panel'),
      title: 'Goals',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          column(Side.home),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.md),
            child: Icon(Icons.sports_soccer_rounded, size: 16, color: p.muted),
          ),
          column(Side.away),
        ],
      ),
    );
  }
}

/// Who has been on top, minute by minute: bars above the line for the home
/// side and below it for the away side, with a dot at each goal. The
/// minutes still to come are left empty, so the chart fills as the match
/// goes on.
class MomentumPanel extends StatelessWidget {
  const MomentumPanel(this.match, {super.key});

  final FootballSnapshot match;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Panel(
      key: const Key('momentum-panel'),
      title: 'Momentum',
      trailing: Text(
        "${match.minute}'",
        style: context.figure.copyWith(fontSize: 12, color: p.muted),
      ),
      child: Column(
        children: [
          _SideLabel(match.home, p),
          const SizedBox(height: 4),
          Semantics(
            label:
                'Momentum by minute. '
                '${match.home.name} above the line, ${match.away.name} below.',
            child: RepaintBoundary(
              child: CustomPaint(
                size: const Size(double.infinity, 92),
                painter: _MomentumPainter(
                  values: match.momentum,
                  total: match.totalMinutes,
                  goals: [
                    for (final g in match.goalEvents)
                      (g.minute + g.added, g.side),
                  ],
                  home: p.tint(match.home.crest.tint),
                  away: p.tint(match.away.crest.tint),
                  line: p.line,
                  goal: p.accent,
                  ground: p.card,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _SideLabel(match.away, p),
        ],
      ),
    );
  }
}

class _SideLabel extends StatelessWidget {
  const _SideLabel(this.team, this.p);

  final Team team;
  final Palette p;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: p.tint(team.crest.tint),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(team.name, style: context.caption.copyWith(fontSize: 11.5)),
    ],
  );
}

class _MomentumPainter extends CustomPainter {
  const _MomentumPainter({
    required this.values,
    required this.total,
    required this.goals,
    required this.home,
    required this.away,
    required this.line,
    required this.goal,
    required this.ground,
  });

  final List<double> values;
  final int total;
  final List<(int, Side)> goals;
  final Color home;
  final Color away;
  final Color line;
  final Color goal;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    final mid = size.height / 2;
    final step = size.width / math.max(total, 1);
    final bar = math.max(step - 1.2, 1.0);
    final hp = Paint()..color = home, ap = Paint()..color = away;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      final h = math.max(v.abs() * (mid - 8), 1.5);
      final x = i * step;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          v >= 0
              ? Rect.fromLTWH(x, mid - h, bar, h)
              : Rect.fromLTWH(x, mid, bar, h),
          const Radius.circular(1.2),
        ),
        v >= 0 ? hp : ap,
      );
    }
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = line
        ..strokeWidth = 1,
    );
    // Half time.
    final half = size.width * (total <= 0 ? .5 : (total / 2) / total);
    canvas.drawLine(
      Offset(half, 6),
      Offset(half, size.height - 6),
      Paint()
        ..color = line
        ..strokeWidth = 1,
    );
    for (final (minute, side) in goals) {
      final x = (minute - .5).clamp(0, total) * step;
      final y = side == Side.home ? 5.0 : size.height - 5;
      canvas
        ..drawCircle(Offset(x, y), 5, Paint()..color = ground)
        ..drawCircle(Offset(x, y), 3.6, Paint()..color = goal);
    }
  }

  @override
  bool shouldRepaint(_MomentumPainter old) =>
      old.values.length != values.length ||
      old.goals.length != goals.length ||
      old.home != home ||
      old.away != away ||
      old.line != line;
}

/// Both elevens on one pitch, the home side at the top, with what each
/// player has done marked on them. The benches follow.
class LineupsView extends StatelessWidget {
  const LineupsView(this.match, {super.key});

  final FootballSnapshot match;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.md,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.lg),
            child: AspectRatio(
              aspectRatio: .66,
              child: LayoutBuilder(
                builder: (context, box) {
                  final size = box.biggest;
                  Offset at(LineupSpot s, Side side) => Offset(
                    size.width *
                        (.08 + .84 * (side == Side.home ? s.x : 1 - s.x)),
                    size.height *
                        (side == Side.home ? .03 + s.y * .47 : .97 - s.y * .47),
                  );
                  return Stack(
                    key: const Key('pitch'),
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _PitchPainter(p.pitch, p.pitchLine),
                        ),
                      ),
                      for (final side in Side.values)
                        for (final s
                            in side == Side.home
                                ? match.homeLineup
                                : match.awayLineup)
                          _OnPitch(
                            spot: s,
                            at: at(s, side),
                            tint: p.tint(match.team(side).crest.tint),
                          ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        for (final side in Side.values)
          Panel(
            title: '${match.team(side).name} bench',
            child: Wrap(
              spacing: Space.lg,
              runSpacing: Space.sm,
              children: [
                for (final b
                    in side == Side.home ? match.homeBench : match.awayBench)
                  Text(
                    '${b.number}  ${b.shortName}',
                    style: context.body.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _OnPitch extends StatelessWidget {
  const _OnPitch({required this.spot, required this.at, required this.tint});

  final LineupSpot spot;
  final Offset at;
  final Color tint;

  static const _width = 76.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = spot;
    final off = s.red || s.replacedBy != null;
    return Positioned(
      left: at.dx - _width / 2,
      top: at.dy - 15,
      width: _width,
      child: Semantics(
        label:
            '${s.player.name}, number ${s.player.number}'
            '${s.goals > 0 ? ', ${s.goals} ${s.goals == 1 ? 'goal' : 'goals'}' : ''}'
            '${s.yellow ? ', booked' : ''}${s.red ? ', sent off' : ''}'
            '${s.replacedBy != null ? ', replaced by ${s.replacedBy!.name}' : ''}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 30,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: off ? tint.withValues(alpha: .55) : tint,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.onTeam, width: 1.4),
                    ),
                    child: Text(
                      '${s.player.number}',
                      style: TextStyle(
                        color: p.onTeam,
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (s.goals > 0)
                    Positioned(
                      right: 16,
                      top: -3,
                      child: _Mark(
                        color: p.card,
                        child: Icon(
                          Icons.sports_soccer_rounded,
                          size: 12,
                          color: p.ink,
                        ),
                      ),
                    ),
                  if (s.yellow || s.red)
                    Positioned(
                      left: 18,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 11,
                        decoration: BoxDecoration(
                          // A booking is the pale wash; a dismissal the
                          // full accent.
                          color: s.red ? p.accent : p.accentWash,
                          borderRadius: BorderRadius.circular(1.5),
                          border: Border.all(color: p.onTeam, width: .8),
                        ),
                      ),
                    ),
                  if (s.replacedBy != null)
                    Positioned(
                      right: 16,
                      bottom: -3,
                      child: _Mark(
                        color: p.card,
                        child: Icon(
                          Icons.swap_vert_rounded,
                          size: 12,
                          color: p.accentInk,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              (s.replacedBy ?? s.player).surname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.onTeam,
                fontSize: 10.5,
                height: 1.1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: 15,
    height: 15,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: child,
  );
}

class _PitchPainter extends CustomPainter {
  const _PitchPainter(this.grass, this.chalk);

  final Color grass;
  final Color chalk;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = grass);
    // Mown stripes.
    final stripe = Paint()..color = chalk.withValues(alpha: .05);
    for (var i = 0; i < 10; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, h * i / 10, w, h / 10), stripe);
    }
    final line = Paint()
      ..color = chalk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final field = Rect.fromLTRB(w * .04, h * .025, w * .96, h * .975);
    canvas
      ..drawRect(field, line)
      ..drawLine(Offset(field.left, h / 2), Offset(field.right, h / 2), line)
      ..drawCircle(Offset(w / 2, h / 2), w * .13, line);
    for (final top in [true, false]) {
      final y = top ? field.top : field.bottom;
      final d = top ? 1.0 : -1.0;
      canvas
        ..drawRect(
          Rect.fromPoints(Offset(w * .22, y), Offset(w * .78, y + d * h * .13)),
          line,
        )
        ..drawRect(
          Rect.fromPoints(Offset(w * .37, y), Offset(w * .63, y + d * h * .05)),
          line,
        );
    }
  }

  @override
  bool shouldRepaint(_PitchPainter old) =>
      old.grass != grass || old.chalk != chalk;
}
