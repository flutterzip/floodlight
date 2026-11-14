import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/app_timing.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/fixture.dart';
import '../../models/format.dart';
import '../../models/league.dart';
import '../../providers/account_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/score_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/live_card.dart';
import '../../widgets/match_row.dart';
import '../../widgets/pressable.dart';
import '../../widgets/rise.dart';
import '../../widgets/rolling_number.dart';
import '../../widgets/sport_icon.dart';
import '../actions.dart';
import '../shell/main_shell.dart';
import '../splash/splash_overlay.dart';
import '../tables/tables_tab.dart';

/// The first tab: what is on now, as a rail of live scoreboards, then every
/// competition with its matches. In order: the greeting, search, the sport
/// filter, Live now, then one section per competition.
class ScoresTab extends ConsumerStatefulWidget {
  const ScoresTab({super.key});

  @override
  ConsumerState<ScoresTab> createState() => _ScoresTabState();
}

class _ScoresTabState extends ConsumerState<ScoresTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: Motion.entrance);
    startWhenRevealed(ref, _enter.forward);
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final board = ref.watch(filteredBoardProvider);
    final sport = ref.watch(sportFilterProvider);
    final competitions = [
      for (final c in ref.watch(competitionsProvider))
        if (sport == null || c.sport == sport) c,
    ];
    final following = ref.watch(followingProvider).valueOrNull ?? const [];
    // Followed teams' matches lead the rail.
    final live = [...board.live]
      ..sort((a, b) {
        int rank(Fixture f) => following.any(f.involves) ? 0 : 1;
        final c = rank(a).compareTo(rank(b));
        return c != 0 ? c : a.kickoff.compareTo(b.kickoff);
      });
    final top = MediaQuery.paddingOf(context).top;

    return TabPage(
      child: RefreshIndicator(
        color: p.accent,
        backgroundColor: p.card,
        edgeOffset: top,
        onRefresh: () => AppTiming.refreshing(
          () async => ref.read(scoresProvider)?.refresh(),
        ),
        child: CustomScrollView(
          key: const Key('scores-list'),
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: top + Space.md)),
            SliverToBoxAdapter(
              child: Rise(
                animation: _enter,
                from: 0,
                to: .5,
                child: const _Header(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.lg)),
            SliverToBoxAdapter(
              child: Rise(
                animation: _enter,
                from: .08,
                to: .58,
                child: const _SearchPill(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.md)),
            SliverToBoxAdapter(
              child: Rise(
                animation: _enter,
                from: .14,
                to: .64,
                child: const _SportChips(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: Space.xl)),
            SliverToBoxAdapter(
              child: Rise(
                animation: _enter,
                from: .22,
                to: .78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Live now'),
                    const SizedBox(height: Space.md),
                    if (live.isEmpty)
                      _Quiet(sport: sport, next: board.upcoming.firstOrNull)
                    else
                      SizedBox(
                        height: LiveCard.size.height,
                        child: ListView.separated(
                          key: const Key('live-rail'),
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.gutter,
                          ),
                          itemCount: live.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: Space.md),
                          itemBuilder: (_, i) =>
                              LiveCard(live[i].id, key: ValueKey(live[i].id)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            for (var i = 0; i < competitions.length; i++)
              SliverToBoxAdapter(
                child: Rise(
                  animation: _enter,
                  from: (.32 + i * .07).clamp(0, .6),
                  child: _CompetitionSection(
                    competition: competitions[i],
                    board: board,
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: Sizes.tabBarReserve),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Welcome, Olympicson", how many matches are live, and the way to You.
class _Header extends ConsumerWidget {
  const _Header();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final profile = ref.watch(profileProvider).valueOrNull;
    final live = ref.watch(boardProvider.select((b) => b.live.length));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile == null ? 'Welcome' : 'Welcome, ${profile.firstName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.display,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    RollingNumber(
                      '$live',
                      key: const Key('live-count'),
                      highlight: p.accentInk,
                      style: context.body.copyWith(
                        color: p.accentInk,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Flexible(
                      child: Text(
                        live == 1 ? ' match live now' : ' matches live now',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.body,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Pressable(
            semanticLabel: 'Your profile',
            onTap: () =>
                ref.read(shellTabProvider.notifier).state = ShellTab.profile,
            child: Avatar(profile: profile, size: 46),
          ),
        ],
      ),
    );
  }
}

/// The pill that grows into the search field.
class _SearchPill extends StatelessWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Pressable(
        key: const Key('search-pill'),
        scale: .98,
        semanticLabel: 'Search teams and competitions',
        onTap: () => openSearch(context),
        child: Hero(
          tag: 'search-field',
          child: Material(
            color: p.field,
            borderRadius: BorderRadius.circular(Radii.pill),
            child: SizedBox(
              height: 50,
              child: Row(
                children: [
                  const SizedBox(width: Space.lg),
                  Icon(Icons.search_rounded, size: 20, color: p.muted),
                  const SizedBox(width: Space.sm + 2),
                  Expanded(
                    child: Text(
                      'Teams, competitions, players',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.body.copyWith(color: p.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SportChips extends ConsumerWidget {
  const _SportChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sport = ref.watch(sportFilterProvider);
    void set(Sport? s) => ref.read(sportFilterProvider.notifier).set(s);
    return SizedBox(
      height: 42,
      // Four chips: built together, so none is missing off the edge.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: Row(
          children: [
            SelectChip(
              key: const Key('sport-all'),
              label: 'All',
              selected: sport == null,
              onTap: () => set(null),
            ),
            for (final s in Sport.values) ...[
              const SizedBox(width: Space.sm),
              SelectChip(
                key: Key('sport-${s.name}'),
                label: s.label,
                icon: sportIcon(s),
                selected: sport == s,
                onTap: () => set(s),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the rail when nothing is being played.
class _Quiet extends ConsumerWidget {
  const _Quiet({required this.sport, required this.next});

  final Sport? sport;
  final Fixture? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final n = next;
    final left = n == null ? 0 : ref.watch(startsInProvider(n.id));
    final home = n == null ? null : ref.watch(teamProvider(n.homeId));
    final away = n == null ? null : ref.watch(teamProvider(n.awayId));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Container(
        key: const Key('nothing-live'),
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(Space.lg),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Row(
          children: [
            Icon(
              sport == null ? Icons.nightlight_round : sportIcon(sport!),
              color: p.muted,
              size: 26,
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sport == null
                        ? 'Nothing live right now'
                        : 'No ${sport!.label.toLowerCase()} live right now',
                    style: context.title,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    home == null || away == null
                        ? 'The next round is on its way.'
                        : '${home.name} v ${away.name} starts in '
                              '${countdown(left)}.',
                    style: context.body,
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

/// One competition: its name, a way to its table, and its matches with the
/// live ones first.
class _CompetitionSection extends ConsumerWidget {
  const _CompetitionSection({required this.competition, required this.board});

  final Competition competition;
  final Board board;

  /// How many matches still to start, and already over, a section shows.
  static const _each = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool mine(Fixture f) => f.competitionId == competition.id;
    final ids = [
      for (final f in board.live.where(mine)) f.id,
      for (final f in board.upcoming.where(mine).take(_each)) f.id,
      for (final f in board.finished.where(mine).take(_each)) f.id,
    ];
    if (ids.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            competition.name,
            action: 'Table',
            onAction: () {
              ref.read(tableCompetitionProvider.notifier).state =
                  competition.id;
              ref.read(shellTabProvider.notifier).state = ShellTab.tables;
            },
          ),
          const SizedBox(height: Space.sm),
          MatchGroup(fixtureIds: ids),
        ],
      ),
    );
  }
}
