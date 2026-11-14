import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/league.dart';
import '../../providers/account_providers.dart';
import '../../providers/score_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/crest.dart';
import '../../widgets/sport_icon.dart';
import '../actions.dart';
import '../shell/main_shell.dart';
import '../tables/tables_tab.dart';

/// What a search can land on.
sealed class SearchHit {
  const SearchHit();
}

class TeamHit extends SearchHit {
  const TeamHit(this.team);
  final Team team;
}

class CompetitionHit extends SearchHit {
  const CompetitionHit(this.competition);
  final Competition competition;
}

class PlayerHit extends SearchHit {
  const PlayerHit(this.player, this.team);
  final Player player;
  final Team team;
}

/// Teams first, then competitions, then players. Every word typed has to
/// be found, and a name that starts with the search beats one that only
/// contains it.
List<SearchHit> search(
  String query, {
  required Iterable<Team> teams,
  required Iterable<Competition> competitions,
}) {
  final words = query.toLowerCase().split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return const [];
  bool has(String text) {
    final t = text.toLowerCase();
    return words.every(t.contains);
  }

  int rank(String name) => name.toLowerCase().startsWith(words.first) ? 0 : 1;
  int byName(String a, String b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : a.compareTo(b);
  }

  final teamHits = [
    for (final t in teams)
      if (has('${t.name} ${t.short} ${t.city}')) t,
  ]..sort((a, b) => byName(a.name, b.name));
  final competitionHits = [
    for (final c in competitions)
      if (has('${c.name} ${c.short} ${c.sport.label} ${c.region}')) c,
  ]..sort((a, b) => byName(a.name, b.name));
  final playerHits = [
    for (final t in teams)
      for (final pl in t.squad)
        if (has(pl.name)) (pl, t),
  ]..sort((a, b) => byName(a.$1.name, b.$1.name));
  return [
    for (final t in teamHits) TeamHit(t),
    for (final c in competitionHits) CompetitionHit(c),
    for (final (pl, t) in playerHits.take(12)) PlayerHit(pl, t),
  ];
}

/// Search grows out of the pill on Scores. Results as you type; recent
/// searches and every competition while the box is empty.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _field.addListener(() => setState(() {}));
    // After the route has settled, so the keyboard does not fight the Hero.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _remember() =>
      ref.read(recentSearchesProvider.notifier).add(_field.text);

  void _open(SearchHit hit) {
    _remember();
    switch (hit) {
      case TeamHit(:final team) || PlayerHit(:final team):
        openTeam(context, team.id);
      case CompetitionHit(:final competition):
        ref.read(tableCompetitionProvider.notifier).state = competition.id;
        Navigator.of(context).pop();
        ref.read(shellTabProvider.notifier).state = ShellTab.tables;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final teams = ref.watch(scoresTeamsProvider);
    final competitions = ref.watch(competitionsProvider);
    final query = _field.text.trim();
    final hits = search(query, teams: teams, competitions: competitions);
    final recent = ref.watch(recentSearchesProvider).valueOrNull ?? const [];

    return Material(
      color: p.paper,
      child: Column(
        children: [
          SizedBox(height: media.padding.top + Space.sm),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, Space.gutter, Space.sm),
            child: Row(
              children: [
                const BackChevron(),
                Expanded(
                  child: Hero(
                    tag: 'search-field',
                    child: Material(
                      color: p.field,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      child: SizedBox(
                        height: 50,
                        child: TextField(
                          key: const Key('search-field'),
                          controller: _field,
                          focusNode: _focus,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _remember(),
                          style: context.body.copyWith(
                            color: p.ink,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Teams, competitions, players',
                            hintStyle: context.body.copyWith(color: p.muted),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              size: 20,
                              color: p.muted,
                            ),
                            suffixIcon: query.isEmpty
                                ? null
                                : IconButton(
                                    key: const Key('search-clear'),
                                    tooltip: 'Clear',
                                    onPressed: _field.clear,
                                    icon: Icon(
                                      Icons.cancel_rounded,
                                      size: 18,
                                      color: p.muted,
                                    ),
                                  ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const Key('search-results'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                top: Space.sm,
                bottom: media.viewInsets.bottom + Sizes.tabBarReserve,
              ),
              children: query.isEmpty
                  ? [
                      if (recent.isNotEmpty) ...[
                        SectionTitle(
                          'Recent',
                          action: 'Clear',
                          onAction: () =>
                              ref.read(recentSearchesProvider.notifier).clear(),
                        ),
                        for (final term in recent)
                          _Line(
                            key: Key('recent-$term'),
                            leading: Icon(
                              Icons.history_rounded,
                              size: 20,
                              color: p.muted,
                            ),
                            title: term,
                            onTap: () => _field.text = term,
                            trailing: IconButton(
                              tooltip: 'Remove $term',
                              onPressed: () => ref
                                  .read(recentSearchesProvider.notifier)
                                  .remove(term),
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: p.muted,
                              ),
                            ),
                          ),
                        const SizedBox(height: Space.lg),
                      ],
                      const SectionTitle('Competitions'),
                      for (final c in competitions)
                        _Line(
                          key: Key('suggest-${c.id}'),
                          leading: Icon(
                            sportIcon(c.sport),
                            size: 20,
                            color: p.ink,
                          ),
                          title: c.name,
                          subtitle: '${c.sport.label}. ${c.region}',
                          onTap: () => _open(CompetitionHit(c)),
                        ),
                    ]
                  : hits.isEmpty
                  ? [
                      EmptyState(
                        key: const Key('no-results'),
                        title: 'Nothing for "$query"',
                        message:
                            'Try a team, a city, a competition or a '
                            "player's name.",
                      ),
                    ]
                  : [
                      for (final hit in hits)
                        switch (hit) {
                          TeamHit(:final team) => _Line(
                            key: Key('hit-team-${team.id}'),
                            leading: CrestBadge(team, size: 30),
                            title: team.name,
                            subtitle: '${team.sport.label}. ${team.city}',
                            onTap: () => _open(hit),
                          ),
                          CompetitionHit(:final competition) => _Line(
                            key: Key('hit-competition-${competition.id}'),
                            leading: Icon(
                              sportIcon(competition.sport),
                              size: 22,
                              color: p.ink,
                            ),
                            title: competition.name,
                            subtitle: 'Competition. ${competition.region}',
                            onTap: () => _open(hit),
                          ),
                          PlayerHit(:final player, :final team) => _Line(
                            key: Key('hit-player-${player.id}'),
                            leading: Icon(
                              Icons.person_outline_rounded,
                              size: 22,
                              color: p.ink,
                            ),
                            title: player.name,
                            subtitle: '${team.name}. Number ${player.number}',
                            onTap: () => _open(hit),
                          ),
                        },
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Every team, for searching.
final scoresTeamsProvider = Provider<List<Team>>((ref) {
  final ids = [for (final c in ref.watch(competitionsProvider)) ...c.teamIds];
  return [for (final id in ids) ?ref.watch(teamProvider(id))];
});

class _Line extends StatelessWidget {
  const _Line({
    super.key,
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: Row(
          children: [
            SizedBox(width: 34, child: Center(child: leading)),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.title,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption,
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    ),
  );
}
