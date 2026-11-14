import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../providers/score_providers.dart';
import '../../widgets/common.dart';
import 'match_tabs.dart';
import 'scoreboard.dart';

enum _Tab { summary, stats, detail, feed }

/// A match: the scoreboard, which shuts to a bar as the page scrolls, over
/// four tabs. Summary, Stats, the sport's own card (line-ups, box score or
/// scorecard) and the full commentary.
///
/// The page watches its match, and the engine only hands over a new one
/// when something has happened, so between events nothing here rebuilds.
class MatchScreen extends ConsumerStatefulWidget {
  const MatchScreen({super.key, required this.fixtureId});

  final String fixtureId;

  @override
  ConsumerState<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends ConsumerState<MatchScreen> {
  var _tab = _Tab.summary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = ref.watch(matchProvider(widget.fixtureId));
    final top = MediaQuery.paddingOf(context).top;
    if (m == null) {
      return const SubPage(
        title: 'Match',
        child: EmptyState(
          title: 'That match has gone',
          message: 'It is no longer on the calendar.',
        ),
      );
    }
    String label(_Tab t) => switch (t) {
      _Tab.summary => 'Summary',
      _Tab.stats => 'Stats',
      _Tab.detail => detailTabLabel(m.sport),
      _Tab.feed => 'Feed',
    };
    final feed = m.feed;

    // The board is dark in both modes: light status bar icons over it.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: p.paper,
        child: CustomScrollView(
          key: const Key('match-scroll'),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _BoardDelegate(
                fixtureId: widget.fixtureId,
                top: top,
                ground: p.board,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsDelegate(
                ground: p.paper,
                child: Segmented<_Tab>(
                  values: _Tab.values,
                  labelOf: label,
                  value: _tab,
                  keyPrefix: 'match-tab',
                  onChanged: (t) => setState(() => _tab = t),
                ),
              ),
            ),
            if (_tab == _Tab.feed)
              feed.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(Space.gutter),
                        child: Text(
                          'Commentary starts with the match.',
                          style: context.body,
                        ),
                      ),
                    )
                  // Newest first, built only as it scrolls into view: a
                  // cricket match runs to two hundred and fifty lines.
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.gutter,
                      ),
                      sliver: SliverList.builder(
                        key: const Key('feed-list'),
                        itemCount: feed.length,
                        itemBuilder: (_, i) {
                          final item = feed[feed.length - 1 - i];
                          return FeedLine(
                            item,
                            key: ValueKey(item.id),
                            match: m,
                          );
                        },
                      ),
                    )
            else
              SliverToBoxAdapter(
                child: switch (_tab) {
                  _Tab.summary => Column(
                    children: [SummaryTab(m), TeamsStrip(m)],
                  ),
                  _Tab.stats => StatsTab(m),
                  _ => detailTab(m),
                },
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

class _BoardDelegate extends SliverPersistentHeaderDelegate {
  const _BoardDelegate({
    required this.fixtureId,
    required this.top,
    required this.ground,
  });

  final String fixtureId;
  final double top;
  final Color ground;

  @override
  double get minExtent => top + Scoreboard.barHeight;

  @override
  double get maxExtent => top + Scoreboard.barHeight + Scoreboard.bodyHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      Scoreboard(
        fixtureId: fixtureId,
        collapse: (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0),
      );

  @override
  bool shouldRebuild(_BoardDelegate old) =>
      old.fixtureId != fixtureId || old.top != top || old.ground != ground;
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  const _TabsDelegate({required this.child, required this.ground});

  final Widget child;
  final Color ground;

  static const _height = 46.0 + Space.md * 2;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      ColoredBox(
        color: ground,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.gutter,
            vertical: Space.md,
          ),
          child: child,
        ),
      );

  // The segmented control is rebuilt by its parent when the tab changes.
  @override
  bool shouldRebuild(_TabsDelegate old) => true;
}
