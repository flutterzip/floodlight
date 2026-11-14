import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/cricket.dart';
import '../../models/league.dart';
import '../../widgets/panel.dart';
import '../../widgets/rolling_number.dart';
import 'basketball_sections.dart' show SideSwitch;

/// The full card for one innings at a time: every batter and how they got
/// out, extras and the total, the fall of wickets, and the bowling.
class ScorecardView extends StatefulWidget {
  const ScorecardView(this.match, {super.key});

  final CricketSnapshot match;

  @override
  State<ScorecardView> createState() => _ScorecardViewState();
}

class _ScorecardViewState extends State<ScorecardView> {
  Side? _side;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = widget.match;
    if (m.innings.isEmpty) {
      return Panel(
        child: Text(
          'The card fills in from the first ball.',
          style: context.body,
        ),
      );
    }
    // Follow the innings in progress until the person chooses one.
    final side = _side ?? m.innings.last.batting;
    final innings = m.inningsOf(side);
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
            side: side,
            onChanged: (s) => setState(() => _side = s),
          ),
        ),
        if (innings == null)
          Panel(
            key: const Key('yet-to-bat'),
            child: Text(
              '${m.team(side).name} are yet to bat.',
              style: context.body,
            ),
          )
        else ...[
          Panel(
            key: const Key('batting-card'),
            title: 'Batting',
            trailing: cells([
              for (final h in ['R', 'B', '4s', '6s', 'SR'])
                Text(h, style: head),
            ]),
            child: Column(
              children: [
                for (final b in innings.batters)
                  if (b.state != BatterState.yetToBat)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${b.player.shortName}${b.onStrike ? ' *' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.title.copyWith(fontSize: 14),
                                ),
                                Text(
                                  b.dismissal,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.caption.copyWith(
                                    fontSize: 11.5,
                                    color: b.state == BatterState.batting
                                        ? p.accentInk
                                        : p.muted,
                                  ),
                                ),
                              ],
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
                Divider(color: p.line),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Expanded(child: Text('Extras', style: context.body)),
                    Text('${innings.extras}', style: cell),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total (${innings.overs} overs)',
                        style: context.title.copyWith(fontSize: 14),
                      ),
                    ),
                    RollingNumber(
                      innings.total,
                      highlight: p.accentInk,
                      style: cell.copyWith(
                        color: p.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (innings.batters.any(
                  (b) => b.state == BatterState.yetToBat,
                )) ...[
                  const SizedBox(height: Space.md),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Yet to bat: ${innings.batters.where((b) => b.state == BatterState.yetToBat).map((b) => b.player.surname).join(', ')}',
                      style: context.caption,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (innings.fallOfWickets.isNotEmpty)
            Panel(
              title: 'Fall of wickets',
              child: Text(
                innings.fallOfWickets.join('   '),
                style: context.body.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          Panel(
            key: const Key('bowling-card'),
            title: 'Bowling',
            trailing: cells([
              for (final h in ['O', 'M', 'R', 'W', 'Econ'])
                Text(h, style: head),
            ]),
            child: Column(
              children: [
                for (final b in innings.bowlers)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${b.player.shortName}${b.bowling ? ' *' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.title.copyWith(fontSize: 14),
                          ),
                        ),
                        cells([
                          roll(b.overs),
                          roll('${b.maidens}'),
                          roll('${b.runs}'),
                          roll('${b.wickets}', strong: true),
                          roll(b.economy.toStringAsFixed(1)),
                        ]),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
