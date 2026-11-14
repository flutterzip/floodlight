import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/app_timing.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/format.dart';
import '../../models/league.dart';
import '../../models/match.dart';
import '../../models/pick.dart';
import '../../providers/account_providers.dart';
import '../../providers/score_providers.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/crest.dart';
import '../../widgets/panel.dart';
import '../../widgets/primary_button.dart';

/// "Home", "Draw" or the away side, in words.
String pickLabel(MatchSnapshot m, PickChoice c) => switch (c) {
  PickChoice.home => m.home.name,
  PickChoice.away => m.away.name,
  PickChoice.draw => 'Draw',
};

/// Your call on the match: make one before it starts, change it until
/// then, and see how it stands after.
class PickCard extends ConsumerWidget {
  const PickCard(this.fixtureId, {super.key});

  final String fixtureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final m = ref.watch(matchProvider(fixtureId));
    if (m == null) return const SizedBox.shrink();
    final pick = ref.watch(pickForProvider(fixtureId));
    final result = ref.watch(pickResultProvider(fixtureId));
    final open = m.stage == MatchStage.upcoming;

    final Widget body;
    if (pick == null) {
      body = open
          ? Row(
              children: [
                Expanded(
                  child: Text(
                    'Who takes it? Call it before the start.',
                    style: context.body,
                  ),
                ),
                const SizedBox(width: Space.md),
                _Small(
                  key: const Key('make-pick'),
                  label: 'Make a pick',
                  onTap: () => showPickSheet(context, fixtureId),
                ),
              ],
            )
          : Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: p.muted),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    'Picks closed at the start. Call the next one early.',
                    style: context.body,
                  ),
                ),
              ],
            );
    } else {
      final (icon, colour, line) = switch (result) {
        PickResult.won => (
          Icons.check_circle_rounded,
          p.positive,
          'You called it',
        ),
        PickResult.lost => (Icons.cancel_rounded, p.muted, 'Not this time'),
        PickResult.open => (
          Icons.how_to_vote_rounded,
          p.accentInk,
          open ? 'Locked in until the start' : 'Riding on this one',
        ),
      };
      body = Row(
        children: [
          Icon(icon, size: 22, color: colour),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pickLabel(m, pick.choice),
                  key: const Key('pick-choice'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.title,
                ),
                const SizedBox(height: 2),
                Text(line, style: context.caption),
              ],
            ),
          ),
          if (open)
            _Small(
              key: const Key('change-pick'),
              label: 'Change',
              onTap: () => showPickSheet(context, fixtureId),
            ),
        ],
      );
    }
    return Panel(title: 'Your pick', child: body);
  }
}

class _Small extends StatelessWidget {
  const _Small({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: p.onPrimary,
        backgroundColor: p.primary,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: AppTheme.font,
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
      ),
      child: Text(label),
    );
  }
}

/// Opens the sheet to make or change a pick.
Future<void> showPickSheet(BuildContext context, String fixtureId) =>
    showAppSheet<void>(
      context,
      title: 'Your pick',
      builder: (_) => _PickSheet(fixtureId),
    );

class _PickSheet extends ConsumerStatefulWidget {
  const _PickSheet(this.fixtureId);

  final String fixtureId;

  @override
  ConsumerState<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends ConsumerState<_PickSheet> {
  PickChoice? _choice;
  bool _busy = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _choice = ref.read(pickForProvider(widget.fixtureId))?.choice;
  }

  Future<void> _save() async {
    final choice = _choice;
    if (choice == null) {
      setState(() => _problem = 'Choose who wins first.');
      return;
    }
    // The sheet may have sat open past the start.
    final m = ref.read(matchProvider(widget.fixtureId));
    if (m == null || m.stage != MatchStage.upcoming) {
      setState(() => _problem = 'This one has started. Picks are closed.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final palette = context.palette;
    final nav = Navigator.of(context);
    try {
      await AppTiming.atLeast(
        AppTiming.savePick,
        ref.read(picksProvider.notifier).choose(widget.fixtureId, choice),
      );
      HapticFeedback.mediumImpact();
      nav.pop();
      showToastOn(
        messenger,
        palette,
        'Pick locked in: ${pickLabel(m, choice)}',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _problem = 'That did not save. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = ref.watch(matchProvider(widget.fixtureId));
    if (m == null) return const SizedBox.shrink();
    final left = ref.watch(startsInProvider(widget.fixtureId));
    final choices = [
      PickChoice.home,
      if (m.chance.draw > 0) PickChoice.draw,
      PickChoice.away,
    ];
    double share(PickChoice c) => switch (c) {
      PickChoice.home => m.chance.home,
      PickChoice.draw => m.chance.draw,
      PickChoice.away => m.chance.away,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            m.stage == MatchStage.upcoming
                ? 'Picks close at the start, in ${countdown(left)}.'
                : 'This one has started.',
            style: context.body,
          ),
          const SizedBox(height: Space.lg),
          for (final c in choices) ...[
            _Choice(
              key: Key('pick-${c.name}'),
              label: pickLabel(m, c),
              team: c.side == null ? null : m.team(c.side!),
              share: share(c),
              selected: _choice == c,
              onTap: _busy
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _choice = c;
                        _problem = null;
                      });
                    },
            ),
            const SizedBox(height: Space.sm),
          ],
          AnimatedSize(
            duration: Motion.short,
            alignment: Alignment.topCenter,
            child: _problem == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: Space.xs),
                    child: Notice(
                      _problem!,
                      icon: Icons.info_outline_rounded,
                      error: true,
                    ),
                  ),
          ),
          const SizedBox(height: Space.md),
          KeyedSubtree(
            key: const Key('save-pick'),
            child: PrimaryButton(
              label: 'Lock it in',
              busy: _busy,
              onPressed: _save,
            ),
          ),
          SizedBox(
            height: MediaQuery.paddingOf(context).bottom > 0 ? 0 : Space.sm,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(
                'For fun. Nothing is staked.',
                style: context.caption.copyWith(color: p.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.team,
    required this.share,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Team? team;
  final double share;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${percent(share)} chance',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: BoxDecoration(
            color: selected ? p.accentWash : p.field,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? p.accent : p.field,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              if (team != null)
                CrestBadge(team!, size: 28)
              else
                SizedBox(
                  width: 28,
                  child: Icon(Icons.drag_handle_rounded, color: p.muted),
                ),
              const SizedBox(width: Space.md),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.title,
                ),
              ),
              Text(
                percent(share),
                style: context.figure.copyWith(color: p.inkSoft),
              ),
              const SizedBox(width: Space.md),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? p.accent : p.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
