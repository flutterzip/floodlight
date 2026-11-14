import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/format.dart';
import '../../models/pick.dart';
import '../../providers/account_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/score_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/crest.dart';
import '../actions.dart';

/// Alerts from the teams you follow: a start, a goal or a milestone, a
/// result.
/// Tap one to open its match, which also marks it read. Swipe one away to
/// clear it.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final alerts = ref.watch(alertsProvider).items;
    final fresh = ref.watch(unreadAlertIdsProvider);
    final now = ref.watch(minuteProvider);
    final unread = fresh.length;

    return SubPage(
      title: 'Alerts',
      trailing: unread == 0
          ? null
          : TextButton(
              key: const Key('alerts-read-all'),
              onPressed: () => ref
                  .read(alertsReadProvider.notifier)
                  .addAll(alerts.map((a) => a.id)),
              style: TextButton.styleFrom(
                foregroundColor: p.accentInk,
                minimumSize: const Size(48, 44),
                textStyle: const TextStyle(
                  fontFamily: AppTheme.font,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
              child: const Text('Mark all read'),
            ),
      child: alerts.isEmpty
          ? const Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  key: Key('no-alerts'),
                  title: 'All quiet',
                  message:
                      'When a team you follow kicks off, scores or finishes, '
                      'it shows here.',
                ),
              ),
            )
          : ListView.builder(
              key: const Key('alerts-list'),
              padding: const EdgeInsets.only(
                top: Space.sm,
                bottom: Sizes.tabBarReserve,
              ),
              itemCount: alerts.length,
              itemBuilder: (context, i) {
                final a = alerts[i];
                final unseen = fresh.contains(a.id);
                final team = ref.watch(teamProvider(a.teamId));
                return Dismissible(
                  key: ValueKey(a.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) =>
                      ref.read(alertsClearedProvider.notifier).addAll([a.id]),
                  background: Container(
                    color: p.field,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: Space.xl),
                    child: Text(
                      'Clear',
                      style: context.title.copyWith(color: p.inkSoft),
                    ),
                  ),
                  child: Material(
                    color: p.paper,
                    child: InkWell(
                      key: Key('alert-${a.id}'),
                      onTap: () {
                        ref.read(alertsReadProvider.notifier).addAll([a.id]);
                        openMatch(context, a.fixtureId);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.gutter,
                          vertical: 13,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Unread is a dot and a heavier title, never
                            // colour alone.
                            SizedBox(
                              width: 14,
                              child: unseen
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: Container(
                                        key: Key('unread-${a.id}'),
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: p.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            if (team != null) CrestBadge(team, size: 32),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.title.copyWith(
                                      fontWeight: unseen
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  if (a.body.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        a.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.body,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${switch (a.kind) {
                                      AlertKind.start => 'Started',
                                      AlertKind.score => 'In play',
                                      AlertKind.result => 'Result',
                                    }}  ·  ${agoLabel(a.at, now)}',
                                    style: context.caption.copyWith(
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
