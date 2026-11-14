import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/league.dart';
import '../../models/match.dart';
import '../../widgets/chance_bar.dart';
import '../../widgets/crest.dart';
import '../../widgets/rolling_number.dart';

/// The picture on each introduction slide, made of the app's own parts and
/// two real teams from the seed.
///
/// [presence] is 1 when the slide is centred and 0 a full page away. The
/// art is built from it, not from a timer, so it follows the finger and
/// runs backwards if the person changes their mind. Composed once at a
/// design size and scaled to fit.
class OnboardingArt extends StatelessWidget {
  const OnboardingArt({
    super.key,
    required this.index,
    required this.presence,
    required this.home,
    required this.away,
  });

  final int index;
  final double presence;
  final Team home;
  final Team away;

  static const _design = Size(300, 300);

  @override
  Widget build(BuildContext context) => Center(
    child: FittedBox(
      child: SizedBox.fromSize(
        size: _design,
        child: switch (index) {
          0 => _ScoreArt(presence, home, away),
          1 => _PillArt(presence, home, away),
          _ => _PickArt(presence, home, away),
        },
      ),
    ),
  );
}

double _slice(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// A scoreboard whose score climbs as the slide arrives, so the first thing
/// anyone sees the app do is roll a digit.
class _ScoreArt extends StatelessWidget {
  const _ScoreArt(this.t, this.home, this.away);

  final double t;
  final Team home;
  final Team away;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Two goals for the home side, then one back.
    final homeGoals = t > .78 ? 2 : (t > .32 ? 1 : 0);
    final awayGoals = t > .56 ? 1 : 0;
    final minute = 12 + (t * 55).round();
    Widget side(Team team) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CrestBadge(team, size: 46),
          const SizedBox(height: 8),
          Text(
            team.short,
            style: context.title.copyWith(color: p.onBoard, fontSize: 14),
          ),
        ],
      ),
    );
    Widget number(int v) => RollingNumber(
      '$v',
      highlight: p.accent,
      style: context.score.copyWith(fontSize: 52),
    );
    return Center(
      child: Opacity(
        opacity: _slice(t, 0, .25),
        child: Transform.translate(
          offset: Offset(
            0,
            24 * (1 - Curves.easeOut.transform(_slice(t, 0, .4))),
          ),
          child: Container(
            width: 284,
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
            decoration: BoxDecoration(
              color: p.board,
              borderRadius: BorderRadius.circular(Radii.xl),
              boxShadow: [
                BoxShadow(
                  color: p.shadow,
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    side(home),
                    number(homeGoals),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ':',
                        style: context.score.copyWith(
                          fontSize: 30,
                          color: p.boardMuted,
                        ),
                      ),
                    ),
                    number(awayGoals),
                    side(away),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: p.boardRaised,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        "$minute'",
                        style: context.figure.copyWith(
                          fontSize: 12.5,
                          color: p.onBoard,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ChanceBar(
                  chance: WinChance(
                    home: .34 + .3 * t,
                    draw: .3 - .12 * t,
                    away: .36 - .18 * t,
                  ),
                  home: home,
                  away: away,
                  onBoard: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A list of matches with the live pill opening over it.
class _PillArt extends StatelessWidget {
  const _PillArt(this.t, this.home, this.away);

  final double t;
  final Team home;
  final Team away;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final open = Curves.easeOutCubic.transform(_slice(t, .45, 1));
    final rows = _slice(t, 0, .5);
    Widget row(Team a, Team b, String score, double appear) => Opacity(
      opacity: _slice(rows, appear, appear + .4),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Row(
          children: [
            CrestBadge(a, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(a.short, style: context.title.copyWith(fontSize: 13)),
            ),
            Text(score, style: context.figure.copyWith(fontSize: 13)),
            Expanded(
              child: Text(
                b.short,
                textAlign: TextAlign.right,
                style: context.title.copyWith(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            CrestBadge(b, size: 20),
          ],
        ),
      ),
    );
    final small = TextStyle(
      fontFamily: AppTheme.font,
      color: p.onIsland,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Stack(
      children: [
        Positioned(
          left: 14,
          right: 14,
          top: 16,
          child: Column(
            children: [
              row(home, away, '2 - 1', 0),
              row(away, home, '0 - 0', .2),
              row(home, away, '1 - 3', .4),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 22,
          child: Center(
            child: Opacity(
              opacity: _slice(t, .3, .55),
              child: Container(
                width: 190 + 80 * open,
                height: 38 + 46 * open,
                padding: EdgeInsets.symmetric(horizontal: 16 + 4 * open),
                decoration: BoxDecoration(
                  color: p.board,
                  borderRadius: BorderRadius.circular(19 + 9 * open),
                  boxShadow: [
                    BoxShadow(
                      color: p.shadow,
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: open < .6
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: p.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${home.short} 2 : 1 ${away.short}',
                              style: small,
                            ),
                          ],
                        ),
                      )
                    : Opacity(
                        opacity: _slice(open, .6, 1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final (team, score) in [
                              (home, '2'),
                              (away, '1'),
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        team.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: small.copyWith(fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      score,
                                      style: small.copyWith(fontSize: 15),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The three calls on a match, one being chosen, and a record ticking up.
class _PickArt extends StatelessWidget {
  const _PickArt(this.t, this.home, this.away);

  final double t;
  final Team home;
  final Team away;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chosen = t > .55;
    Widget choice(
      String label,
      Team? team,
      String share,
      bool on,
      double appear,
    ) => Opacity(
      opacity: _slice(t, appear, appear + .3),
      child: Container(
        height: 52,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? p.accentWash : p.card,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: on ? p.accent : p.card, width: 1.5),
        ),
        child: Row(
          children: [
            if (team != null)
              CrestBadge(team, size: 24)
            else
              SizedBox(
                width: 24,
                child: Icon(
                  Icons.drag_handle_rounded,
                  size: 20,
                  color: p.muted,
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: context.title.copyWith(fontSize: 14)),
            ),
            Text(
              share,
              style: context.figure.copyWith(color: p.inkSoft, fontSize: 13),
            ),
            const SizedBox(width: 10),
            Icon(
              on
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: on ? p.accent : p.muted,
            ),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Column(
        children: [
          choice(home.name, home, '52%', chosen, 0),
          choice('Draw', null, '24%', false, .12),
          choice(away.name, away, '24%', false, .24),
          const SizedBox(height: 10),
          Opacity(
            opacity: _slice(t, .5, .8),
            child: Row(
              children: [
                for (final (label, value) in [
                  ('Right', t > .9 ? '7' : '6'),
                  ('Wrong', '2'),
                  ('In a row', t > .9 ? '4' : '3'),
                ])
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RollingNumber(
                          value,
                          alignment: Alignment.centerLeft,
                          highlight: p.accentInk,
                          style: context.figure.copyWith(fontSize: 24),
                        ),
                        Text(label, style: context.caption),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
