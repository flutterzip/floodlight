import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:floodlight/kit/kit.dart';

import '../config/app_theme.dart';
import '../config/design_tokens.dart';
import '../config/motion.dart';
import '../models/league.dart';
import '../providers/account_providers.dart';
import 'crest.dart';

/// Where a followed team lands: the Following tab's icon in the glass bar.
final followTargetKey = GlobalKey(debugLabel: 'follow-target');

/// Ticks each time a team lands in Following, so the tab can pop.
final followLanded = ValueNotifier<int>(0);

/// Follows [team], or stops following it.
///
/// Following throws a copy of the crest from [from] into the Following tab
/// and adds the team when it lands, so the tab ticks on arrival and not
/// before. With reduce motion, or when either end is off screen, it lands
/// at once.
void toggleFollow(
  BuildContext context,
  WidgetRef ref, {
  required Team team,
  required GlobalKey from,
}) {
  final following = ref.read(followingProvider.notifier);
  if (ref.read(isFollowingProvider(team.id))) {
    HapticFeedback.selectionClick();
    following.unfollow(team.id);
    return;
  }
  HapticFeedback.lightImpact();
  FlyTo.launch(
    context,
    from: from,
    to: followTargetKey,
    endScale: .3,
    child: CrestBadge(team, size: 64),
    onLanded: () {
      following.follow(team.id);
      followLanded.value++;
      HapticFeedback.selectionClick();
    },
  );
}

/// "Follow" until the team is followed, then "Following".
class FollowButton extends ConsumerWidget {
  const FollowButton({
    super.key,
    required this.team,
    required this.from,
    this.onBoard = false,
  });

  final Team team;

  /// The crest the flight lifts off from.
  final GlobalKey from;
  final bool onBoard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final on = ref.watch(isFollowingProvider(team.id));
    final fg = on ? (onBoard ? p.onBoard : p.ink) : p.onAccent;
    return Semantics(
      button: true,
      label: on ? 'Stop following ${team.name}' : 'Follow ${team.name}',
      excludeSemantics: true,
      child: GestureDetector(
        key: Key('follow-${team.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => toggleFollow(context, ref, team: team, from: from),
        child: AnimatedContainer(
          duration: Motion.short,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: BoxDecoration(
            color: on ? (onBoard ? p.boardRaised : p.field) : p.accent,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: Motion.short,
                switchInCurve: Curves.easeOutBack,
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Icon(
                  on ? Icons.star_rounded : Icons.star_border_rounded,
                  key: ValueKey(on),
                  size: 18,
                  color: on ? p.accent : fg,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                on ? 'Following' : 'Follow',
                style: context.title.copyWith(fontSize: 14, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
