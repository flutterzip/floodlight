import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_theme.dart';
import '../config/design_tokens.dart';
import '../models/format.dart';
import '../models/league.dart';
import '../models/match.dart';
import '../providers/account_providers.dart';
import '../providers/score_providers.dart';
import '../screens/actions.dart';
import 'crest.dart';
import 'live.dart';
import 'pressable.dart';
import 'rolling_number.dart';

/// One match in a list: when, who, and the score, rolling as it changes.
///
/// It watches its own match and nothing else, so a goal in one row repaints
/// that row's number and leaves the rest of the list alone.
class MatchRow extends ConsumerWidget {
  const MatchRow(this.fixtureId, {super.key, this.showCompetition = false});

  final String fixtureId;

  /// Names the competition under the teams, where the list does not.
  final bool showCompetition;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final m = ref.watch(matchProvider(fixtureId));
    if (m == null) return const SizedBox.shrink();
    final leader = m.stage == MatchStage.upcoming ? null : m.leader;
    final picked = ref.watch(pickForProvider(fixtureId)) != null;
    final competition = showCompetition
        ? ref.watch(competitionProvider(m.fixture.competitionId))
        : null;

    Widget side(Side s) {
      final team = m.team(s);
      final score = m.score(s);
      final strong = leader == null || leader == s;
      return Row(
        children: [
          CrestBadge(team, size: 22),
          const SizedBox(width: Space.sm + 2),
          Expanded(
            child: Text(
              team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.title.copyWith(
                fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
                color: strong ? p.ink : p.inkSoft,
              ),
            ),
          ),
          // The score and its overs shrink as one piece if they must.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 132),
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
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  if (score.main.isNotEmpty)
                    RollingNumber(
                      score.main,
                      key: Key('score-$fixtureId-${s.name}'),
                      highlight: p.accentInk,
                      style: context.figure.copyWith(
                        fontSize: 15,
                        fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                        color: strong ? p.ink : p.inkSoft,
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
      key: Key('match-$fixtureId'),
      scale: .985,
      semanticLabel: '${m.home.name} against ${m.away.name}, ${_spoken(m)}',
      onTap: () => openMatch(context, fixtureId),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.md, 12, Space.lg, 12),
        color: p.card,
        child: Row(
          children: [
            SizedBox(width: 58, child: _When(m)),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  side(Side.home),
                  const SizedBox(height: 7),
                  side(Side.away),
                  if (competition != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${competition.name}, round ${m.fixture.round}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption.copyWith(fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
            if (picked) ...[
              const SizedBox(width: Space.sm),
              Icon(
                Icons.how_to_vote_rounded,
                size: 15,
                color: p.muted,
                semanticLabel: 'You have a pick on this match',
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _spoken(MatchSnapshot m) => switch (m.stage) {
    MatchStage.upcoming => 'starts at ${timeLabel(m.fixture.kickoff)}',
    MatchStage.finished => m.headline,
    _ => 'live, ${m.headline}',
  };
}

/// The left column of a row: the clock while it is on, the start time
/// before, the result mark after.
class _When extends ConsumerWidget {
  const _When(this.match);

  final MatchSnapshot match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final id = match.id;
    switch (match.stage) {
      case MatchStage.upcoming:
        final left = ref.watch(startsInProvider(id));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timeLabel(match.fixture.kickoff),
              style: context.figure.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 3),
            Text(
              'in ${countdown(left)}',
              style: context.caption.copyWith(
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      case MatchStage.finished:
        return Text(
          match.shortStatus,
          style: context.figure.copyWith(fontSize: 13, color: p.muted),
        );
      case MatchStage.live || MatchStage.paused:
        final clock = ref.watch(matchClockProvider(id));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const LiveDot(size: 5),
                  Text(
                    match.stage == MatchStage.paused ? 'BREAK' : 'LIVE',
                    style: context.label.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.1,
                      color: p.accentInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                clock,
                maxLines: 1,
                style: context.figure.copyWith(
                  fontSize: 12.5,
                  color: p.accentInk,
                ),
              ),
            ),
          ],
        );
    }
  }
}

/// A group of rows on one card, with hairlines between them.
class MatchGroup extends StatelessWidget {
  const MatchGroup({
    super.key,
    required this.fixtureIds,
    this.showCompetition = false,
  });

  final List<String> fixtureIds;
  final bool showCompetition;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: ColoredBox(
          color: p.card,
          child: Column(
            children: [
              for (var i = 0; i < fixtureIds.length; i++) ...[
                if (i > 0)
                  Divider(color: p.line, indent: Space.md, endIndent: Space.md),
                MatchRow(
                  fixtureIds[i],
                  key: ValueKey(fixtureIds[i]),
                  showCompetition: showCompetition,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
