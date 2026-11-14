import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:floodlight/kit/kit.dart';

import '../config/app_theme.dart';
import '../config/motion.dart';
import '../models/league.dart';
import '../models/match.dart';
import '../providers/account_providers.dart';
import '../providers/score_providers.dart';
import '../screens/actions.dart';
import '../screens/shell/main_shell.dart';
import 'rolling_number.dart';

/// Matches the person waved away from the pill this session.
final islandDismissedProvider = StateProvider<Set<String>>((_) => const {});

/// The match in the pill: the one pinned, or failing that a followed team's
/// match while it is live.
final islandMatchProvider = Provider<String?>((ref) {
  // No pill for the match being looked at: its board is right there.
  final showing = ref.watch(showingMatchProvider);
  final pinned = ref.watch(pinnedProvider).valueOrNull;
  if (pinned != null) return pinned == showing ? null : pinned;
  final following = ref.watch(followingProvider).valueOrNull ?? const [];
  final dismissed = ref.watch(islandDismissedProvider);
  for (final f in ref.watch(boardProvider).live) {
    if (f.id != showing &&
        !dismissed.contains(f.id) &&
        following.any(f.involves)) {
      return f.id;
    }
  }
  return null;
});

/// The live pill above the tab bar: a match kept in view on every tab. Tap
/// it and it opens into the scoreboard; tap that to go to the match.
class MatchIsland extends ConsumerStatefulWidget {
  const MatchIsland({super.key, required this.fixtureId});

  final String fixtureId;

  @override
  ConsumerState<MatchIsland> createState() => _MatchIslandState();
}

class _MatchIslandState extends ConsumerState<MatchIsland> {
  bool _open = false;

  void _close() {
    final id = widget.fixtureId;
    HapticFeedback.selectionClick();
    if (ref.read(pinnedProvider).valueOrNull == id) {
      ref.read(pinnedProvider.notifier).set(null);
    }
    ref.read(islandDismissedProvider.notifier).update((s) => {...s, id});
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final id = widget.fixtureId;
    final m = ref.watch(matchProvider(id));
    if (m == null) return const SizedBox.shrink();
    final clock = ref.watch(matchClockProvider(id));
    final on = p.onIsland;
    final small = TextStyle(
      fontFamily: AppTheme.font,
      color: on,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final when = switch (m.stage) {
      MatchStage.upcoming => 'Soon',
      MatchStage.finished => m.shortStatus,
      _ => clock,
    };
    final width = (MediaQuery.sizeOf(context).width - 40).clamp(250.0, 400.0);

    Widget number(Side s, double size) => RollingNumber(
      m.score(s).main.isEmpty ? '-' : m.score(s).main,
      highlight: p.accent,
      style: small.copyWith(fontSize: size, fontWeight: FontWeight.w700),
    );

    // Scaled to fit rather than laid out to fit: at a large text size the
    // line shrinks as one piece instead of losing its end.
    final compact = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (m.stage.inPlay) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: p.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(m.home.short, style: small),
            const SizedBox(width: 6),
            number(Side.home, 13),
            Text(
              '  :  ',
              style: small.copyWith(color: on.withValues(alpha: .5)),
            ),
            number(Side.away, 13),
            const SizedBox(width: 6),
            Text(m.away.short, style: small),
            const SizedBox(width: 10),
            Text(
              when,
              maxLines: 1,
              style: small.copyWith(
                color: on.withValues(alpha: .65),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );

    Widget line(Side s) => Row(
      children: [
        Expanded(
          child: Text(
            m.team(s).name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: small.copyWith(fontSize: 14.5),
          ),
        ),
        if (m.score(s).detail.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              m.score(s).detail,
              style: small.copyWith(
                fontSize: 11.5,
                color: on.withValues(alpha: .6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        number(s, 15.5),
      ],
    );

    final open = Padding(
      // The open pill has deep round corners: the text keeps well inside
      // them, or the first line sits in the curve.
      padding: const EdgeInsets.fromLTRB(30, 18, 14, 17),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(Side.home),
                line(Side.away),
                Text(
                  '$when. ${m.headline}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small.copyWith(
                    fontSize: 12,
                    color: on.withValues(alpha: .65),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Remove from the live pill',
            excludeSemantics: true,
            child: GestureDetector(
              key: const Key('island-close'),
              behavior: HitTestBehavior.opaque,
              onTap: _close,
              child: SizedBox(
                width: 40,
                height: 48,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: on.withValues(alpha: .7),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      key: const Key('match-island'),
      button: true,
      label:
          '${m.home.name} ${m.score(Side.home).main}, '
          '${m.away.name} ${m.score(Side.away).main}, $when',
      // Only as tall as what it is showing, so it leaves no gap when shut.
      child: AnimatedSize(
        duration: Motion.medium,
        curve: Motion.settle,
        alignment: Alignment.bottomCenter,
        // The pill's shadow falls outside its box: do not cut it.
        clipBehavior: Clip.none,
        child: MorphingIsland(
          maxHeight: _open ? 116 : MorphingIsland.compactHeight + 8,
          onTap: () {
            HapticFeedback.selectionClick();
            if (_open) openMatch(context, id);
            setState(() => _open = !_open);
          },
          view: _open
              ? IslandView(id: 'open', size: Size(width, 108), child: open)
              : IslandView(
                  id: 'compact',
                  size: Size(
                    m.sport == Sport.cricket ? 268 : 236,
                    MorphingIsland.compactHeight,
                  ),
                  child: compact,
                ),
        ),
      ),
    );
  }
}
