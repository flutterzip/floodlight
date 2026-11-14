import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/league.dart';
import '../../models/pick.dart';
import '../../providers/account_providers.dart';
import '../../providers/score_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/crest.dart';
import '../../widgets/follow.dart';
import '../../widgets/linger.dart';
import '../../widgets/match_row.dart';
import '../../widgets/panel.dart';
import '../../widgets/pressable.dart';
import '../../widgets/removable.dart';
import '../../widgets/rolling_number.dart';
import '../actions.dart';
import '../match/pick_card.dart';

enum FollowingView { teams, picks }

final followingViewProvider = StateProvider<FollowingView>(
  (_) => FollowingView.teams,
);

/// Your side of the app: the teams you follow, each with the match it is
/// in or has next, and the picks you have made with how they turned out.
class FollowingTab extends ConsumerWidget {
  const FollowingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final view = ref.watch(followingViewProvider);
    return TabPage(
      child: ListView(
        key: const Key('following-list'),
        padding: EdgeInsets.only(
          top: media.padding.top + Space.md,
          bottom: Sizes.tabBarReserve,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text('Following', style: context.display),
          ),
          const SizedBox(height: Space.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Segmented<FollowingView>(
              values: FollowingView.values,
              labelOf: (v) => v == FollowingView.teams ? 'Teams' : 'Picks',
              value: view,
              keyPrefix: 'following',
              onChanged: (v) =>
                  ref.read(followingViewProvider.notifier).state = v,
            ),
          ),
          const SizedBox(height: Space.xl),
          if (view == FollowingView.teams) const _Teams() else const _Picks(),
        ],
      ),
    );
  }
}

class _Teams extends ConsumerWidget {
  const _Teams();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(followingProvider).valueOrNull ?? const <String>[];
    // A few to start with: the leaders of each table not yet followed.
    final suggested = <Team>[
      for (final c in ref.watch(competitionsProvider))
        ...ref
            .watch(tableProvider(c.id))
            .map((r) => r.team)
            .where((t) => !ids.contains(t.id))
            .take(1),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ids.isEmpty)
          EmptyState(
            key: const Key('no-teams'),
            title: 'Nobody followed yet',
            message:
                'Follow a team and its matches lead your scores, sit in the '
                'live pill and send you alerts.',
            action: 'Find a team',
            onAction: () => openSearch(context),
          )
        else
          for (final id in ids) _TeamCard(id, key: ValueKey(id)),
        if (suggested.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          const SectionTitle('Top of the tables'),
          const SizedBox(height: Space.sm),
          for (final t in suggested) _Suggestion(t, key: ValueKey('s-${t.id}')),
        ],
      ],
    );
  }
}

/// A followed team with the match that matters for it right now.
class _TeamCard extends ConsumerWidget {
  const _TeamCard(this.teamId, {super.key});

  final String teamId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final team = ref.watch(teamProvider(teamId));
    if (team == null) return const SizedBox.shrink();
    final focus = ref.watch(teamFocusProvider(teamId));
    final row = ref.watch(standingProvider(teamId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.md,
      ),
      child: Container(
        key: Key('followed-$teamId'),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Pressable(
              scale: .985,
              semanticLabel: team.name,
              onTap: () => openTeam(context, teamId),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.md,
                  Space.md,
                  4,
                  Space.sm,
                ),
                child: Row(
                  children: [
                    CrestBadge(team, size: 34),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.title.copyWith(fontSize: 15.5),
                          ),
                          Text(
                            row == null
                                ? team.city
                                : '${_ordinal(row.position)}, played ${row.played}',
                            style: context.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: Key('unfollow-$teamId'),
                      tooltip: 'Stop following ${team.name}',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        final notifier = ref.read(followingProvider.notifier);
                        final at =
                            ref
                                .read(followingProvider)
                                .valueOrNull
                                ?.indexOf(teamId) ??
                            0;
                        notifier.unfollow(teamId);
                        showToast(
                          context,
                          'No longer following ${team.name}',
                          icon: Icons.star_border_rounded,
                          onUndo: () => notifier.restore(teamId, at),
                        );
                      },
                      icon: Icon(Icons.star_rounded, color: p.accent, size: 22),
                    ),
                  ],
                ),
              ),
            ),
            if (focus != null) ...[
              Divider(color: p.line, indent: Space.md, endIndent: Space.md),
              MatchRow(focus.id),
            ],
          ],
        ),
      ),
    );
  }

  static String _ordinal(int n) {
    final suffix = n % 100 >= 11 && n % 100 <= 13
        ? 'th'
        : switch (n % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$n$suffix';
  }
}

class _Suggestion extends ConsumerStatefulWidget {
  const _Suggestion(this.team, {super.key});

  final Team team;

  @override
  ConsumerState<_Suggestion> createState() => _SuggestionState();
}

class _SuggestionState extends ConsumerState<_Suggestion> {
  final _crest = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final team = widget.team;
    final competition = ref.watch(scoresProviderCompetition(team.id));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.sm,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(Space.md, 10, Space.md, 10),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        child: Row(
          children: [
            KeyedSubtree(key: _crest, child: CrestBadge(team, size: 34)),
            const SizedBox(width: Space.md),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => openTeam(context, team.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.title,
                    ),
                    Text(
                      competition ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption,
                    ),
                  ],
                ),
              ),
            ),
            FollowButton(team: team, from: _crest),
          ],
        ),
      ),
    );
  }
}

/// The name of the competition a team plays in.
final scoresProviderCompetition = Provider.family<String?, String>((ref, id) {
  for (final c in ref.watch(competitionsProvider)) {
    if (c.teamIds.contains(id)) return c.name;
  }
  return null;
});

class _Picks extends ConsumerStatefulWidget {
  const _Picks();

  @override
  ConsumerState<_Picks> createState() => _PicksState();
}

class _PicksState extends ConsumerState<_Picks> {
  final _linger = Linger();
  final _removed = <String, Pick>{};

  Future<void> _remove(Pick pick) async {
    final notifier = ref.read(picksProvider.notifier);
    final live = [
      for (final p in ref.read(picksProvider).valueOrNull ?? const <Pick>[])
        p.id,
    ];
    HapticFeedback.selectionClick();
    setState(() {
      _removed[pick.id] = pick;
      _linger.hold(pick.id, live);
    });
    final at = await notifier.remove(pick.id);
    if (!mounted) return;
    showToast(
      context,
      'Pick removed',
      icon: Icons.delete_outline_rounded,
      onUndo: () => notifier.restore(pick, at),
      onClosed: () {
        if (!mounted) return;
        setState(() {
          _linger.release(pick.id);
          _removed.remove(pick.id);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final live = ref.watch(picksProvider).valueOrNull ?? const <Pick>[];
    final record = ref.watch(pickRecordProvider);
    final byId = {..._removed, for (final k in live) k.id: k};
    final rows = _linger.rows([for (final k in live) k.id]);
    final settled = record.won + record.lost;

    Widget figure(String label, String value, {Key? key}) => Expanded(
      child: Figure(
        label: label,
        value: RollingNumber(
          value,
          key: key,
          alignment: Alignment.centerLeft,
          highlight: p.accentInk,
          style: context.figure.copyWith(fontSize: 22),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          key: const Key('pick-record'),
          title: 'Your record',
          child: Row(
            children: [
              figure('Right', '${record.won}', key: const Key('picks-won')),
              figure('Wrong', '${record.lost}'),
              figure('Open', '${record.open}'),
              figure(
                'Hit rate',
                settled == 0 ? '-' : '${(100 * record.won / settled).round()}%',
              ),
            ],
          ),
        ),
        if (rows.isEmpty)
          const EmptyState(
            key: Key('no-picks'),
            title: 'No picks yet',
            message:
                'Open a match that has not started and call the winner. '
                'Your record builds here.',
          )
        else
          for (final id in rows)
            if (byId[id] case final pick?)
              Removable(
                key: ValueKey(id),
                gone: _linger.isGone(id),
                child: _PickRow(pick: pick, onRemove: () => _remove(pick)),
              ),
      ],
    );
  }
}

class _PickRow extends ConsumerWidget {
  const _PickRow({required this.pick, required this.onRemove});

  final Pick pick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final m = ref.watch(matchProvider(pick.fixtureId));
    if (m == null) return const SizedBox.shrink();
    final result = pick.resultFor(m);
    final team = pick.choice.side == null ? null : m.team(pick.choice.side!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.sm,
      ),
      child: Pressable(
        key: Key('pick-row-${pick.fixtureId}'),
        scale: .985,
        semanticLabel:
            '${m.home.name} against ${m.away.name}. You picked '
            '${pickLabel(m, pick.choice)}. ${result.name}',
        onTap: () => openMatch(context, pick.fixtureId),
        child: Container(
          padding: const EdgeInsets.fromLTRB(Space.md, Space.md, 2, Space.md),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            children: [
              if (team != null)
                CrestBadge(team, size: 32)
              else
                SizedBox(
                  width: 32,
                  child: Icon(Icons.drag_handle_rounded, color: p.muted),
                ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickLabel(m, pick.choice),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.title,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.home.short} ${m.score(Side.home).main} '
                      '${m.score(Side.home).main.isEmpty ? 'v' : '-'} '
                      '${m.score(Side.away).main} ${m.away.short}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.caption.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: switch (result) {
                  PickResult.won => 'Right',
                  PickResult.lost => 'Wrong',
                  PickResult.open => m.stage.inPlay ? 'Live' : 'Open',
                },
                live: result == PickResult.open && m.stage.inPlay,
                muted: result == PickResult.lost,
              ),
              IconButton(
                key: Key('remove-pick-${pick.fixtureId}'),
                tooltip: 'Remove this pick',
                onPressed: onRemove,
                icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
