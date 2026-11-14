import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/format.dart';
import '../../models/league.dart';
import '../../models/match.dart';
import '../../providers/account_providers.dart';
import '../../providers/score_providers.dart';
import '../../widgets/chance_bar.dart';
import '../../widgets/crest.dart';
import '../../widgets/live.dart';
import '../../widgets/live_card.dart';
import '../../widgets/match_island.dart';
import '../../widgets/rolling_number.dart';
import '../actions.dart';
import 'score_flare.dart';

/// The scoreboard at the head of a match page.
///
/// [collapse] runs 0 (open, the full board) to 1 (a single bar pinned under
/// the status bar, with the score still rolling in it). The numbers are
/// their own widgets and repaint on their own; nothing here rebuilds for a
/// clock tick except the clock.
class Scoreboard extends ConsumerWidget {
  const Scoreboard({
    super.key,
    required this.fixtureId,
    required this.collapse,
  });

  final String fixtureId;
  final double collapse;

  static const barHeight = 54.0;
  static const bodyHeight = 236.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final m = ref.watch(matchProvider(fixtureId));
    final top = MediaQuery.paddingOf(context).top;
    if (m == null) return ColoredBox(color: p.board);
    final competition = ref.watch(competitionProvider(m.fixture.competitionId));
    // The body is gone by the time the bar is two thirds shut.
    final body = (1 - collapse * 1.5).clamp(0.0, 1.0);
    final bar = ((collapse - .55) / .45).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        BoardSurface(fixtureId: fixtureId, radius: 0),
        if (body > 0)
          Positioned(
            left: 0,
            right: 0,
            top: top + barHeight - 4,
            height: bodyHeight,
            child: Opacity(
              opacity: Curves.easeIn.transform(body),
              child: Transform.translate(
                offset: Offset(0, -26 * (1 - body)),
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: bodyHeight,
                  maxHeight: bodyHeight,
                  child: _Body(m),
                ),
              ),
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: top,
          height: barHeight,
          child: Row(
            children: [
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: p.onBoard,
                ),
              ),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 1 - bar,
                      child: Text(
                        competition == null
                            ? ''
                            : '${competition.name}, round ${m.fixture.round}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption.copyWith(color: p.boardMuted),
                      ),
                    ),
                    if (bar > 0) Opacity(opacity: bar, child: _Compact(m)),
                  ],
                ),
              ),
              _PinButton(fixtureId),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ],
    );
  }
}

/// Keeps or drops this match from the live pill.
class _PinButton extends ConsumerWidget {
  const _PinButton(this.fixtureId);

  final String fixtureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final pinned = ref.watch(pinnedProvider).valueOrNull == fixtureId;
    return IconButton(
      key: const Key('pin-match'),
      tooltip: pinned ? 'Remove from the live pill' : 'Keep in the live pill',
      onPressed: () {
        HapticFeedback.selectionClick();
        ref
            .read(islandDismissedProvider.notifier)
            .update((s) => {...s}..remove(fixtureId));
        ref.read(pinnedProvider.notifier).set(pinned ? null : fixtureId);
      },
      icon: AnimatedSwitcher(
        duration: Motion.short,
        switchInCurve: Curves.easeOutBack,
        transitionBuilder: (child, a) =>
            ScaleTransition(scale: a, child: child),
        child: Icon(
          pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
          key: ValueKey(pinned),
          size: 20,
          color: pinned ? p.accent : p.onBoard,
        ),
      ),
    );
  }
}

/// The score in one line, for the bar when the board is shut.
class _Compact extends ConsumerWidget {
  const _Compact(this.match);

  final MatchSnapshot match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final m = match;
    final style = context.figure.copyWith(fontSize: 15, color: p.onBoard);
    final quiet = style.copyWith(
      color: p.boardMuted,
      fontWeight: FontWeight.w500,
      fontSize: 12.5,
    );
    final clock = ref.watch(matchClockProvider(m.id));
    Widget number(Side s) => RollingNumber(
      m.score(s).main.isEmpty ? '-' : m.score(s).main,
      highlight: p.accent,
      style: style.copyWith(fontWeight: FontWeight.w700),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(m.home.short, style: style),
          const SizedBox(width: 8),
          number(Side.home),
          Text('  :  ', style: quiet),
          number(Side.away),
          const SizedBox(width: 8),
          Text(m.away.short, style: style),
          const SizedBox(width: 12),
          Text(
            m.stage == MatchStage.upcoming
                ? timeLabel(m.fixture.kickoff)
                : clock,
            style: quiet,
          ),
        ],
      ),
    );
  }
}

/// The open board: two crests, the score between them, the state of play
/// and who is likely to win.
class _Body extends StatelessWidget {
  const _Body(this.match);

  final MatchSnapshot match;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = match;
    // Cricket's scores are too wide for the middle: each sits under its
    // own crest instead, and the middle carries the overs.
    final wide = m.sport == Sport.cricket;

    Widget side(Side s) => Expanded(
      child: GestureDetector(
        key: Key('board-team-${s.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => openTeam(context, m.team(s).id),
        child: Column(
          children: [
            CrestBadge(m.team(s), size: 52),
            const SizedBox(height: Space.sm),
            Text(
              m.team(s).name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: context.title.copyWith(color: p.onBoard, fontSize: 13.5),
            ),
            if (wide && m.stage != MatchStage.upcoming) ...[
              const SizedBox(height: 6),
              RollingNumber(
                m.score(s).main.isEmpty ? '-' : m.score(s).main,
                key: Key('board-score-${s.name}'),
                highlight: p.accent,
                reserve: '000/0',
                alignment: Alignment.center,
                style: context.score.copyWith(fontSize: 26, letterSpacing: -.6),
              ),
              Text(
                m.score(s).main.isEmpty ? 'Yet to bat' : m.score(s).detail,
                style: context.caption.copyWith(
                  color: p.boardMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.md, 0, Space.md, Space.lg),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: ScoreFlare(m)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    side(Side.home),
                    SizedBox(width: wide ? 96 : 150, child: _Middle(m)),
                    side(Side.away),
                  ],
                ),
              ],
            ),
          ),
          Text(
            m.headline,
            key: const Key('board-headline'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.body.copyWith(color: p.boardMuted, fontSize: 13.5),
          ),
          const SizedBox(height: Space.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: ChanceBar(
              chance: m.chance,
              home: m.home,
              away: m.away,
              labels: true,
              onBoard: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// The middle of the board: the score (or the start time), and the clock.
class _Middle extends ConsumerWidget {
  const _Middle(this.match);

  final MatchSnapshot match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final m = match;
    final wide = m.sport == Sport.cricket;
    final clock = ref.watch(matchClockProvider(m.id));

    if (m.stage == MatchStage.upcoming) {
      final left = ref.watch(startsInProvider(m.id));
      return Column(
        children: [
          const SizedBox(height: 6),
          Text(
            timeLabel(m.fixture.kickoff),
            style: context.score.copyWith(fontSize: 34, letterSpacing: -.8),
          ),
          const SizedBox(height: 8),
          Text(
            'Starts in',
            style: context.caption.copyWith(color: p.boardMuted),
          ),
          RollingNumber(
            countdown(left),
            key: const Key('board-countdown'),
            alignment: Alignment.center,
            style: context.figure.copyWith(color: p.onBoard, fontSize: 15),
          ),
        ],
      );
    }

    Widget number(Side s) => RollingNumber(
      m.score(s).main,
      key: Key('board-score-${s.name}'),
      highlight: p.accent,
      style: context.score.copyWith(
        fontSize: m.sport == Sport.basketball ? 38 : 50,
      ),
    );
    return Column(
      children: [
        if (wide)
          const SizedBox(height: 14)
        else
          SizedBox(
            height: 58,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  number(Side.home),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Text(
                      ':',
                      style: context.score.copyWith(
                        fontSize: 30,
                        color: p.boardMuted,
                      ),
                    ),
                  ),
                  number(Side.away),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: p.boardRaised,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.stage.inPlay) const LiveDot(size: 6),
              Flexible(
                child: Text(
                  m.stage == MatchStage.finished ? m.shortStatus : clock,
                  key: const Key('board-clock'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.figure.copyWith(
                    fontSize: 12.5,
                    color: p.onBoard,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          m.status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.caption.copyWith(color: p.boardMuted, fontSize: 11.5),
        ),
      ],
    );
  }
}
