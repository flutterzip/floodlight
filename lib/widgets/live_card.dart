import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../config/design_tokens.dart';
import '../models/league.dart';
import '../providers/score_providers.dart';
import '../screens/actions.dart';
import 'chance_bar.dart';
import 'crest.dart';
import 'live.dart';
import 'pressable.dart';
import 'rolling_number.dart';

/// The ground the scoreboard stands on. One Hero carries it from a live
/// card to the match page, so the page grows out of the card.
class BoardSurface extends StatelessWidget {
  const BoardSurface({
    super.key,
    required this.fixtureId,
    this.radius = Radii.xl,
  });

  final String fixtureId;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Hero(
      tag: 'board-$fixtureId',
      // Only the plain shape flies; its corner eases from the card's to
      // the page's square top.
      flightShuttleBuilder: (_, animation, direction, from, to) {
        final a = (from.widget as Hero).child as _Ground;
        final b = (to.widget as Hero).child as _Ground;
        return AnimatedBuilder(
          animation: animation,
          builder: (_, _) => _Ground(
            color: p.board,
            radius: direction == HeroFlightDirection.push
                ? a.radius + (b.radius - a.radius) * animation.value
                : b.radius + (a.radius - b.radius) * (1 - animation.value),
          ),
        );
      },
      child: _Ground(color: p.board, radius: radius),
    );
  }
}

class _Ground extends StatelessWidget {
  const _Ground({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// A live match as a small scoreboard, for the rail at the top of Scores.
class LiveCard extends ConsumerWidget {
  const LiveCard(this.fixtureId, {super.key});

  final String fixtureId;

  static const size = Size(292, 178);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final m = ref.watch(matchProvider(fixtureId));
    if (m == null) return SizedBox.fromSize(size: size);
    final competition = ref.watch(competitionProvider(m.fixture.competitionId));
    final clock = ref.watch(matchClockProvider(fixtureId));
    final leader = m.leader;

    Widget side(Side s) {
      final score = m.score(s);
      final strong = leader == null || leader == s;
      return Row(
        children: [
          CrestBadge(m.team(s), size: 28),
          const SizedBox(width: Space.md),
          Expanded(
            child: Text(
              m.team(s).name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.title.copyWith(
                fontSize: 15.5,
                color: strong ? p.onBoard : p.boardMuted,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (score.detail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        score.detail,
                        style: context.caption.copyWith(
                          color: p.boardMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  RollingNumber(
                    score.main.isEmpty ? '-' : score.main,
                    key: Key('card-score-$fixtureId-${s.name}'),
                    highlight: p.accent,
                    style: context.score.copyWith(
                      fontSize: 24,
                      letterSpacing: -.5,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                      color: strong ? p.onBoard : p.boardMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Pressable(
      key: Key('live-card-$fixtureId'),
      scale: .97,
      semanticLabel:
          'Live: ${m.home.name} against ${m.away.name}, ${m.headline}',
      onTap: () => openMatch(context, fixtureId),
      child: SizedBox.fromSize(
        size: size,
        child: Stack(
          children: [
            Positioned.fill(child: BoardSurface(fixtureId: fixtureId)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          (competition?.name ?? '').toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.label.copyWith(
                            fontSize: 9.5,
                            letterSpacing: 1.3,
                            color: p.boardMuted,
                          ),
                        ),
                      ),
                      const LiveDot(size: 6),
                      Text(
                        clock,
                        style: context.figure.copyWith(
                          fontSize: 12.5,
                          color: p.onBoard,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  side(Side.home),
                  const SizedBox(height: 8),
                  side(Side.away),
                  const Spacer(),
                  Text(
                    m.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.caption.copyWith(
                      color: p.boardMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 9),
                  ChanceBar(
                    chance: m.chance,
                    home: m.home,
                    away: m.away,
                    height: 4,
                    onBoard: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
