import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/fixture.dart';
import '../../models/format.dart';
import '../../models/league.dart';
import '../../models/match.dart';
import '../../providers/core_providers.dart';
import '../../providers/score_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/crest.dart';
import '../../widgets/follow.dart';
import '../../widgets/match_row.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/rolling_number.dart';
import '../actions.dart';
import '../match/match_tabs.dart' show FormDots;

/// A team: where it stands, the match it is in or has next, its season
/// result by result, and its squad. Follow it and its crest flies to the
/// Following tab.
class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key, required this.teamId});

  final String teamId;

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  final _crest = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final team = ref.watch(teamProvider(widget.teamId));
    if (team == null) {
      return const SubPage(
        title: 'Team',
        child: EmptyState(
          title: 'No such team',
          message: 'It may have left the competition.',
        ),
      );
    }
    final scores = ref.watch(scoresProvider)!;
    final competition = scores.competitionOf(team.id);
    final row = ref.watch(standingProvider(team.id));
    final focus = ref.watch(teamFocusProvider(team.id));
    final season = ref.watch(teamSeasonProvider(team.id));
    final starters = switch (team.sport) {
      Sport.basketball => 5,
      _ => 11,
    };

    Widget figure(String label, String value) => Expanded(
      child: Figure(
        label: label,
        value: RollingNumber(
          value,
          alignment: Alignment.centerLeft,
          highlight: p.accentInk,
          style: context.figure.copyWith(fontSize: 20),
        ),
      ),
    );

    return SubPage(
      title: team.name,
      child: ListView(
        key: const Key('team-list'),
        padding: const EdgeInsets.only(
          top: Space.lg,
          bottom: Sizes.tabBarReserve,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Row(
              children: [
                KeyedSubtree(key: _crest, child: CrestBadge(team, size: 68)),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        competition.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.title,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${team.ground}, ${team.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption,
                      ),
                      const SizedBox(height: Space.md),
                      FollowButton(team: team, from: _crest),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          if (row != null)
            Panel(
              key: const Key('team-standing'),
              title: 'This season',
              trailing: FormDots(row.form, size: 18),
              child: Row(
                children: [
                  figure('Position', '${row.position}'),
                  figure('Played', '${row.played}'),
                  figure('Won', '${row.won}'),
                  figure(
                    team.sport == Sport.basketball ? 'Lost' : 'Points',
                    team.sport == Sport.basketball
                        ? '${row.lost}'
                        : '${row.points}',
                  ),
                ],
              ),
            ),
          if (focus != null) ...[
            const SizedBox(height: Space.sm),
            const SectionTitle('Now and next'),
            const SizedBox(height: Space.sm),
            MatchGroup(fixtureIds: [focus.id]),
          ],
          const SizedBox(height: Space.xl),
          const SectionTitle('Season'),
          const SizedBox(height: Space.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Container(
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(Radii.lg),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < season.length; i++) ...[
                    if (i > 0)
                      Divider(
                        color: p.line,
                        indent: Space.md,
                        endIndent: Space.md,
                      ),
                    _SeasonRow(fixture: season[i], teamId: team.id),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          const SectionTitle('Squad'),
          const SizedBox(height: Space.sm),
          Panel(
            key: const Key('team-squad'),
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.sm,
              Space.lg,
              Space.sm,
            ),
            child: Column(
              children: [
                for (var i = 0; i < team.squad.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${team.squad[i].number}',
                            style: context.figure.copyWith(color: p.muted),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            team.squad[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.title.copyWith(
                              fontSize: 14,
                              fontWeight: i < starters
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        Text(team.squad[i].role, style: context.caption),
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

/// One match of the season from this team's side: the round, who and
/// where, and the result or the start time.
class _SeasonRow extends ConsumerWidget {
  const _SeasonRow({required this.fixture, required this.teamId});

  final Fixture fixture;
  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final f = fixture;
    final side = f.sideOf(teamId)!;
    final opponent = ref.watch(teamProvider(f.teamId(side.other)));
    final m = ref.watch(matchProvider(f.id));
    if (opponent == null || m == null) return const SizedBox.shrink();

    final Widget trailing;
    switch (m.stage) {
      case MatchStage.upcoming:
        trailing = Text(
          timeLabel(f.kickoff),
          style: context.figure.copyWith(fontSize: 13, color: p.muted),
        );
      case MatchStage.finished:
        final t = m.tally;
        final mine = side == Side.home ? t.home : t.away;
        final theirs = side == Side.home ? t.away : t.home;
        final (letter, colour) = mine > theirs
            ? ('W', p.positive)
            : mine == theirs
            ? ('D', p.muted)
            : ('L', p.muted);
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${m.score(side).main} - ${m.score(side.other).main}',
              style: context.figure.copyWith(fontSize: 13),
            ),
            const SizedBox(width: Space.sm),
            SizedBox(
              width: 14,
              child: Text(
                letter,
                textAlign: TextAlign.center,
                style: context.figure.copyWith(fontSize: 13, color: colour),
              ),
            ),
          ],
        );
      case MatchStage.live || MatchStage.paused:
        trailing = Row(
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
            const SizedBox(width: 6),
            Text(
              '${m.score(side).main.isEmpty ? '-' : m.score(side).main} - '
              '${m.score(side.other).main.isEmpty ? '-' : m.score(side.other).main}',
              style: context.figure.copyWith(fontSize: 13, color: p.accentInk),
            ),
          ],
        );
    }

    return Pressable(
      key: Key('season-${f.id}'),
      scale: .985,
      semanticLabel:
          'Round ${f.round}, ${side == Side.home ? 'at home to' : 'away to'} '
          '${opponent.name}',
      onTap: () => openMatch(context, f.id),
      child: Container(
        color: p.card,
        padding: const EdgeInsets.fromLTRB(Space.md, 10, Space.lg, 10),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                '${f.round}',
                style: context.figure.copyWith(fontSize: 12.5, color: p.muted),
              ),
            ),
            SizedBox(
              width: 22,
              child: Text(
                side == Side.home ? 'H' : 'A',
                style: context.caption,
              ),
            ),
            CrestBadge(opponent, size: 20),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(
                opponent.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.title.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
