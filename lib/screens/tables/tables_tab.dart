import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/league.dart';
import '../../models/standing.dart';
import '../../providers/account_providers.dart';
import '../../providers/score_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/crest.dart';
import '../../widgets/match_row.dart';
import '../../widgets/pressable.dart';
import '../../widgets/rolling_number.dart';
import '../../widgets/sport_icon.dart';
import '../actions.dart';

/// The competition whose table is showing, or null for the first.
final tableCompetitionProvider = StateProvider<String?>((_) => null);

/// League tables. Nothing here is stored: each row is added up from the
/// season's results, so when a match ends on Scores the table has already
/// moved.
class TablesTab extends ConsumerWidget {
  const TablesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final competitions = ref.watch(competitionsProvider);
    final media = MediaQuery.of(context);
    if (competitions.isEmpty) return const TabPage(child: SizedBox.shrink());
    final chosen = ref.watch(tableCompetitionProvider);
    final competition = competitions.firstWhere(
      (c) => c.id == chosen,
      orElse: () => competitions.first,
    );
    final board = ref.watch(boardProvider);
    final rows = ref.watch(tableProvider(competition.id));
    final round = [
      for (final f in board.all)
        if (f.competitionId == competition.id) f,
    ];
    // This round's matches: the ones on now, else the next to start.
    final current = round.isEmpty
        ? null
        : (board.live
                      .where((f) => f.competitionId == competition.id)
                      .firstOrNull ??
                  board.upcoming
                      .where((f) => f.competitionId == competition.id)
                      .firstOrNull ??
                  round.first)
              .round;
    final ids = [
      for (final f in round)
        if (f.round == current) f,
    ]..sort((a, b) => a.index.compareTo(b.index));

    return TabPage(
      child: ListView(
        key: const Key('tables-list'),
        padding: EdgeInsets.only(
          top: media.padding.top + Space.md,
          bottom: Sizes.tabBarReserve,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text('Tables', style: context.display),
          ),
          const SizedBox(height: Space.lg),
          SizedBox(
            height: 42,
            // A handful of chips: built together, so none is missing off
            // the edge.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Row(
                children: [
                  for (final (i, c) in competitions.indexed) ...[
                    if (i > 0) const SizedBox(width: Space.sm),
                    SelectChip(
                      key: Key('table-${c.id}'),
                      label: c.short,
                      icon: sportIcon(c.sport),
                      selected: c.id == competition.id,
                      onTap: () =>
                          ref.read(tableCompetitionProvider.notifier).state =
                              c.id,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(competition.name, style: context.heading),
                const SizedBox(height: 2),
                Text(
                  current == null
                      ? competition.region
                      : '${competition.region}. Round $current of '
                            '${2 * (competition.teamIds.length - 1)}',
                  style: context.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          LeagueTable(competition: competition, rows: rows),
          if (ids.isNotEmpty) ...[
            const SizedBox(height: Space.xxl),
            SectionTitle('Round $current'),
            const SizedBox(height: Space.sm),
            MatchGroup(fixtureIds: [for (final f in ids) f.id]),
          ],
        ],
      ),
    );
  }
}

/// A table for one competition, with the columns its sport keeps.
class LeagueTable extends ConsumerWidget {
  const LeagueTable({super.key, required this.competition, required this.rows});

  final Competition competition;
  final List<StandingRow> rows;

  static const _cell = 27.0;
  static const _wide = 40.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final style = TableStyle.of(competition.sport);
    final following = ref.watch(followingProvider).valueOrNull ?? const [];
    final head = context.caption.copyWith(fontSize: 11.5);
    // Signed and decimal columns need the room.
    double width(String column) =>
        const {'GD', 'Pct', 'Diff', 'NRR'}.contains(column) ? _wide : _cell;

    Widget cells(List<Widget> values) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < values.length; i++)
          SizedBox(
            width: width(style.columns[i]),
            child: Align(alignment: Alignment.centerRight, child: values[i]),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Container(
        key: Key('league-table-${competition.id}'),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.md, 12, Space.lg, 8),
              child: Row(
                children: [
                  SizedBox(width: 20, child: Text('#', style: head)),
                  Expanded(child: Text('Team', style: head)),
                  cells([for (final c in style.columns) Text(c, style: head)]),
                ],
              ),
            ),
            for (final r in rows) ...[
              Divider(color: p.line, indent: Space.md, endIndent: Space.md),
              Pressable(
                key: Key('table-row-${r.team.id}'),
                scale: .985,
                semanticLabel:
                    '${r.position}. ${r.team.name}, played ${r.played}, '
                    '${r.points} points',
                onTap: () => openTeam(context, r.team.id),
                child: Container(
                  color: p.card,
                  padding: const EdgeInsets.fromLTRB(
                    Space.md,
                    11,
                    Space.lg,
                    11,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          '${r.position}',
                          style: context.figure.copyWith(
                            fontSize: 13,
                            color: p.muted,
                          ),
                        ),
                      ),
                      CrestBadge(r.team, size: 22),
                      const SizedBox(width: Space.sm + 2),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                r.team.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.title.copyWith(fontSize: 14),
                              ),
                            ),
                            if (following.contains(r.team.id))
                              Padding(
                                padding: const EdgeInsets.only(left: 5),
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: p.accent,
                                  semanticLabel: 'Following',
                                ),
                              ),
                            if (r.playing)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: p.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      cells([
                        for (final (i, v) in style.cells(r).indexed)
                          RollingNumber(
                            v,
                            highlight: p.accentInk,
                            style: context.figure.copyWith(
                              fontSize: 13.5,
                              // The column the table is ranked on.
                              color:
                                  i == style.columns.length - 1 ||
                                      style.columns[i] == 'Pct'
                                  ? p.ink
                                  : p.inkSoft,
                              fontWeight: i == style.columns.length - 1
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                            ),
                          ),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
