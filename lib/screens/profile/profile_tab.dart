import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../config/motion.dart';
import '../../models/pick.dart';
import '../../providers/account_providers.dart';
import '../../providers/media_providers.dart';
import '../../providers/reset.dart';
import '../../providers/session_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/panel.dart';
import '../../widgets/rolling_number.dart';
import '../actions.dart';
import '../auth/auth_screen.dart';
import '../following/following_tab.dart';
import '../onboarding/onboarding_screen.dart';
import '../shell/main_shell.dart';
import 'avatar_sheet.dart';
import 'edit_profile_sheet.dart';

abstract final class ProfileKeys {
  static const edit = Key('profile-edit');
  static const alerts = Key('profile-alerts');
  static const teams = Key('profile-teams');
  static const picks = Key('profile-picks');
  static const reset = Key('profile-reset');
  static const signOut = Key('profile-sign-out');
}

/// You: photo and details, your record, what you follow, which alerts you
/// want, appearance, and the way out.
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  /// Leaves the shell for [page]. The shell stays alive under the
  /// cross-fade and [then] runs once it has gone, so nothing blanks
  /// mid-flight.
  static Future<void> _leave(
    BuildContext context,
    Widget page,
    Future<void> Function(ProviderContainer) then,
  ) async {
    // The page's own ref is disposed with it: act through the container.
    final container = ProviderScope.containerOf(context, listen: false);
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushReplacement(handOffRoute(page));
    await Future<void>.delayed(
      Motion.handOff + const Duration(milliseconds: 50),
    );
    await then(container);
    container.read(shellTabProvider.notifier).state = ShellTab.scores;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final profile = ref.watch(profileProvider).valueOrNull;
    final teams = ref.watch(followingProvider).valueOrNull?.length ?? 0;
    final picks = ref.watch(picksProvider).valueOrNull?.length ?? 0;
    final record = ref.watch(pickRecordProvider);
    final unread = ref.watch(unreadAlertsProvider);
    final prefs =
        ref.watch(alertPrefsProvider).valueOrNull ?? const AlertPrefs();
    final hasPhoto =
        (profile?.avatar.isNotEmpty ?? false) ||
        ref.watch(pendingAvatarProvider) != null;

    void toTab(FollowingView view) {
      ref.read(followingViewProvider.notifier).state = view;
      ref.read(shellTabProvider.notifier).state = ShellTab.following;
    }

    String count(int n) => n == 0 ? 'None yet' : '$n';
    void setPrefs(AlertPrefs next) {
      HapticFeedback.selectionClick();
      ref.read(alertPrefsProvider.notifier).set(next);
    }

    Widget figure(String label, String value) => Expanded(
      child: Figure(
        label: label,
        value: RollingNumber(
          value,
          alignment: Alignment.centerLeft,
          highlight: p.accentInk,
          style: context.figure.copyWith(fontSize: 22),
        ),
      ),
    );

    return TabPage(
      child: ListView(
        key: const Key('profile-list'),
        padding: EdgeInsets.only(
          top: media.padding.top + Space.lg,
          bottom: media.padding.bottom + Sizes.tabBarReserve,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Change profile photo',
                  child: GestureDetector(
                    key: AvatarKeys.avatar,
                    onTap: () => showAvatarSheet(context, hasPhoto: hasPhoto),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Avatar(profile: profile, size: 76),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: p.ink,
                              shape: BoxShape.circle,
                              border: Border.all(color: p.paper, width: 2),
                            ),
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 14,
                              color: p.paper,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.display.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        profile?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.caption,
                      ),
                      if (profile?.phone.isNotEmpty ?? false)
                        Text(
                          profile!.phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.caption,
                        ),
                    ],
                  ),
                ),
                RoundIcon(
                  key: ProfileKeys.edit,
                  icon: Icons.edit_outlined,
                  label: 'Edit your details',
                  onTap: profile == null
                      ? null
                      : () => showEditProfileSheet(context, profile),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.xl),
          Panel(
            key: const Key('profile-record'),
            title: 'Your picks',
            child: Row(
              children: [
                figure('Right', '${record.won}'),
                figure('Wrong', '${record.lost}'),
                figure('Open', '${record.open}'),
                figure('In a row', '${record.streak}'),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          _Group(
            children: [
              _Row(
                key: ProfileKeys.teams,
                icon: Icons.star_border_rounded,
                label: 'Teams you follow',
                value: count(teams),
                onTap: () => toTab(FollowingView.teams),
              ),
              _Row(
                key: ProfileKeys.picks,
                icon: Icons.how_to_vote_outlined,
                label: 'Picks',
                value: count(picks),
                onTap: () => toTab(FollowingView.picks),
              ),
              _Row(
                key: ProfileKeys.alerts,
                icon: Icons.notifications_none_rounded,
                label: 'Alerts',
                value: unread == 0 ? null : '$unread new',
                flag: unread > 0,
                onTap: () => openAlerts(context),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          _Heading('Alert me about'),
          _Group(
            children: [
              _Toggle(
                key: const Key('alerts-starts'),
                label: 'Match starts',
                value: prefs.starts,
                onChanged: (v) => setPrefs(prefs.copyWith(starts: v)),
              ),
              _Toggle(
                key: const Key('alerts-scores'),
                label: 'Goals and big moments',
                value: prefs.scores,
                onChanged: (v) => setPrefs(prefs.copyWith(scores: v)),
              ),
              _Toggle(
                key: const Key('alerts-results'),
                label: 'Results',
                value: prefs.results,
                onChanged: (v) => setPrefs(prefs.copyWith(results: v)),
              ),
            ],
          ),
          const SizedBox(height: Space.xl),
          _Heading('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Segmented<ThemeMode>(
              values: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              labelOf: (m) => switch (m) {
                ThemeMode.system => 'Auto',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              value: ref.watch(themeModeProvider),
              keyPrefix: 'appearance',
              onChanged: (m) => ref.read(themeModeProvider.notifier).set(m),
            ),
          ),
          const SizedBox(height: Space.xl),
          _Group(
            children: [
              _Row(
                key: ProfileKeys.reset,
                icon: Icons.restart_alt_rounded,
                label: 'Reset demo data',
                onTap: () async {
                  final yes = await confirmRemove(
                    context,
                    title: 'Reset demo data?',
                    message:
                        'The teams you follow, your picks, alerts and details '
                        'go back to how they started, and you are signed out.',
                    action: 'Reset everything',
                  );
                  if (!yes || !context.mounted) return;
                  await _leave(
                    context,
                    const OnboardingScreen(),
                    resetDemoData,
                  );
                },
              ),
              _Row(
                key: ProfileKeys.signOut,
                icon: Icons.logout_rounded,
                label: 'Sign out',
                onTap: () {
                  HapticFeedback.selectionClick();
                  _leave(
                    context,
                    const AuthScreen(),
                    (c) => c.read(sessionProvider.notifier).signOut(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.md),
    child: Text(
      text.toUpperCase(),
      style: context.label.copyWith(color: context.palette.muted),
    ),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(color: p.line, indent: Space.lg),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            const SizedBox(width: Space.lg),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.title,
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: p.accent,
            ),
            const SizedBox(width: Space.md),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.flag = false,
  });

  final IconData icon;
  final String label;
  final String? value;

  /// Something here wants attention: the value is set in the accent with a
  /// dot before it.
  final bool flag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: value == null ? label : '$label, $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: [
              const SizedBox(width: Space.lg),
              Icon(icon, size: 20, color: p.ink),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.title,
                ),
              ),
              if (flag) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (value != null)
                Text(
                  value!,
                  style: context.caption.copyWith(
                    color: flag ? p.accentInk : null,
                    fontWeight: flag ? FontWeight.w700 : null,
                  ),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.muted),
              const SizedBox(width: Space.md),
            ],
          ),
        ),
      ),
    );
  }
}
