import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:floodlight/kit/kit.dart';

import '../../config/app_theme.dart';
import '../../config/motion.dart';
import '../../config/design_tokens.dart';
import '../../providers/account_providers.dart';
import '../../widgets/follow.dart';
import '../../widgets/match_island.dart';
import '../actions.dart';
import '../following/following_tab.dart';
import '../profile/profile_tab.dart';
import '../scores/scores_tab.dart';
import '../splash/splash_overlay.dart';
import '../tables/tables_tab.dart';

enum ShellTab {
  scores('Scores', Icons.scoreboard_rounded),
  tables('Tables', Icons.leaderboard_rounded),
  following('Following', Icons.star_rounded),
  profile('You', Icons.person_rounded);

  const ShellTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

final shellTabProvider = StateProvider<ShellTab>((_) => ShellTab.scores);

/// One navigator per tab. Pages pushed from a tab (a match, a team, the
/// alerts) open inside it, so the glass bar and the live pill stay, the
/// Following tab is always there for a crest to fly into, and each tab
/// keeps its own history.
final tabNavigatorKeys = {
  for (final t in ShellTab.values)
    t: GlobalKey<NavigatorState>(debugLabel: 'tab-${t.name}'),
};

/// The name of the page on top in each tab, kept by an observer on each
/// tab's navigator.
final tabTopRouteProvider = StateProvider<Map<ShellTab, String?>>(
  (_) => const {},
);

/// The match whose page is on screen right now, if one is.
final showingMatchProvider = Provider<String?>((ref) {
  final name = ref.watch(tabTopRouteProvider)[ref.watch(shellTabProvider)];
  const prefix = 'match:';
  return name != null && name.startsWith(prefix)
      ? name.substring(prefix.length)
      : null;
});

/// Notes which page is on top of a tab. The route is the truth: nothing a
/// page does in its own lifecycle has to stay in step with it.
class _TopRoute extends NavigatorObserver {
  _TopRoute(this.tab, this.container);

  final ShellTab tab;
  final ProviderContainer container;

  void _note(Route<dynamic>? top) {
    final name = top?.settings.name;
    // After the frame: a provider must not change while the tree builds.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigator == null) return;
      container
          .read(tabTopRouteProvider.notifier)
          .update((m) => {...m, tab: name});
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _note(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _note(previousRoute);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _note(navigator?.widget == null ? null : previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _note(newRoute);
}

/// The navigator of the tab on screen. Use it from anywhere, including a
/// sheet that lives on the root navigator, to open a page within the shell.
NavigatorState tabNavigator(BuildContext context) {
  final tab = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(shellTabProvider);
  return tabNavigatorKeys[tab]!.currentState ?? Navigator.of(context);
}

/// Scores, Tables, Following and You, under a floating glass tab bar whose
/// separate pane is Alerts. The live pill rides just above the bar.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  /// Tabs are built the first time they are opened, then kept.
  final _visited = <ShellTab>{};
  final _watchers = <ShellTab, _TopRoute>{};
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

  static Widget _page(ShellTab t) => switch (t) {
    ShellTab.scores => const ScoresTab(),
    ShellTab.tables => const TablesTab(),
    ShellTab.following => const FollowingTab(),
    ShellTab.profile => const ProfileTab(),
  };

  Widget _tab(ShellTab t) {
    final key = tabNavigatorKeys[t]!;
    // Android back and the iOS edge swipe pop inside the tab first.
    return NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => key.currentState?.maybePop(),
      child: Navigator(
        key: key,
        // Nested navigators need their own controller for Heroes to fly.
        observers: [
          HeroController(),
          _watchers[t] ??= _TopRoute(
            t,
            ProviderScope.containerOf(context, listen: false),
          ),
        ],
        onGenerateRoute: (settings) =>
            MaterialPageRoute(settings: settings, builder: (_) => _page(t)),
      ),
    );
  }

  void _select(int index) =>
      ref.read(shellTabProvider.notifier).state = ShellTab.values[index];

  /// Tapping the tab you are on goes back to its first page.
  void _reselect(int index) => tabNavigatorKeys[ShellTab.values[index]]!
      .currentState
      ?.popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tab = ref.watch(shellTabProvider);
    final unread = ref.watch(unreadAlertsProvider);
    final island = ref.watch(islandMatchProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    _visited.add(tab);
    final rise = CurvedAnimation(
      parent: _enter,
      curve: const Interval(.35, 1, curve: Curves.easeOutCubic),
    );
    return Scaffold(
      // Pages handle the keyboard themselves; the bar never rides up on it.
      resizeToAvoidBottomInset: false,
      backgroundColor: p.paper,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: tab.index,
              children: [
                for (final t in ShellTab.values)
                  // Hidden tabs stay mounted; without this their pages would
                  // offer Heroes to a flight in another tab.
                  HeroMode(
                    enabled: t == tab,
                    child: _visited.contains(t)
                        ? _tab(t)
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          // The live pill, just above the bar, on every tab.
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom + 10 + LiquidGlassTabBar.height + Space.sm,
            child: FadeTransition(
              opacity: rise,
              child: AnimatedSwitcher(
                duration: Motion.medium,
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(begin: .86, end: 1.0).animate(a),
                    child: child,
                  ),
                ),
                child: island == null
                    ? const SizedBox.shrink()
                    : Center(
                        key: ValueKey(island),
                        child: MatchIsland(fixtureId: island),
                      ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: bottom + 10,
            child: FadeTransition(
              opacity: rise,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, .6),
                  end: Offset.zero,
                ).animate(rise),
                child: LayoutBuilder(
                  builder: (context, box) {
                    // Where the kit lays the tabs out: a bar beside the
                    // round action pane, the tabs sharing it equally.
                    const h = LiquidGlassTabBar.height;
                    final tabWidth =
                        (box.maxWidth - h - 12 - 12) / ShellTab.values.length;
                    final starX =
                        6 + tabWidth * (ShellTab.following.index + .5);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        LiquidGlassTabBar(
                          currentIndex: tab.index,
                          onChanged: _select,
                          onReselected: _reselect,
                          settings: LiquidGlassSettings(tint: p.glassTint),
                          items: [
                            for (final t in ShellTab.values)
                              GlassTabItem(icon: t.icon, label: t.label),
                          ],
                          action: Icons.notifications_none_rounded,
                          actionLabel: unread == 0
                              ? 'Alerts'
                              : 'Alerts, $unread new',
                          onAction: () => openAlerts(context),
                        ),
                        Positioned(
                          left: starX - 22,
                          top: 4,
                          width: 44,
                          height: 44,
                          child: const IgnorePointer(child: _FollowTarget()),
                        ),
                        if (unread > 0)
                          Positioned(
                            right: 11,
                            top: 11,
                            child: IgnorePointer(child: _Badge(count: unread)),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sits over the Following tab's icon: the point crests fly to. A ring
/// opens from it each time one lands.
class _FollowTarget extends StatelessWidget {
  const _FollowTarget();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(key: followTargetKey, dimension: 24),
        ValueListenableBuilder<int>(
          valueListenable: followLanded,
          builder: (context, landed, _) => landed == 0
              ? const SizedBox.shrink()
              : TweenAnimationBuilder<double>(
                  key: ValueKey(landed),
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.long,
                  curve: Curves.easeOut,
                  builder: (_, t, _) => Container(
                    width: 20 + 34 * t,
                    height: 20 + 34 * t,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: p.accent.withValues(alpha: 1 - t),
                        width: 2.5 * (1 - t) + .5,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      key: const Key('alerts-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.accent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: p.onAccent,
          fontSize: 10.5,
          height: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
