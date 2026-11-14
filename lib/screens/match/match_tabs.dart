import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/design_tokens.dart';
import '../../models/basketball.dart';
import '../../models/cricket.dart';
import '../../models/football.dart';
import '../../models/league.dart';
import '../../models/match.dart';
import '../../models/standing.dart';
import '../../providers/score_providers.dart';
import '../../widgets/crest.dart';
import '../../widgets/live.dart';
import '../../widgets/panel.dart';
import '../../widgets/rolling_number.dart';
import '../actions.dart';
import 'basketball_sections.dart';
import 'cricket_scorecard.dart';
import 'cricket_sections.dart';
import 'football_sections.dart';
import 'pick_card.dart';

/// The first tab: what matters most right now for this sport, your pick,
/// and the moments that decided things.
class SummaryTab extends StatelessWidget {
  const SummaryTab(this.match, {super.key});

  final MatchSnapshot match;

  @override
  Widget build(BuildContext context) {
    final m = match;
    final before = m.stage == MatchStage.upcoming;
    return Column(
      children: [
        if (!before)
          ...switch (m) {
            FootballSnapshot() => [GoalsPanel(m), MomentumPanel(m)],
            BasketballSnapshot() => [QuartersPanel(m), LeadPanel(m)],
            CricketSnapshot() => [CreasePanel(m), WormPanel(m)],
            _ => const <Widget>[],
          },
        PickCard(m.id),
        if (before) FormPanel(m) else KeyMoments(m),
      ],
    );
  }
}

/// The moments worth an alert, newest first.
class KeyMoments extends StatelessWidget {
  const KeyMoments(this.match, {super.key});

  final MatchSnapshot match;

  /// Enough to tell the story without becoming the whole feed.
  static const _most = 8;

  @override
  Widget build(BuildContext context) {
    final major = [
      for (final f in match.feed.reversed)
        if (f.major) f,
    ].take(_most).toList();
    if (major.isEmpty) return const SizedBox.shrink();
    return Panel(
      key: const Key('key-moments'),
      title: 'Key moments',
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.sm,
        Space.lg,
        Space.md,
      ),
      child: Column(
        children: [
          for (final f in major) FeedLine(f, match: match, dense: true),
        ],
      ),
    );
  }
}

/// How the two sides come into the match: where they stand and their last
/// five results, read from the table.
class FormPanel extends ConsumerWidget {
  const FormPanel(this.match, {super.key});

  final MatchSnapshot match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    Widget side(Side s) {
      final team = match.team(s);
      final row = ref.watch(standingProvider(team.id));
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            CrestBadge(team, size: 24),
            const SizedBox(width: Space.md),
            Expanded(
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
                    row == null || row.played == 0
                        ? 'First match of the season'
                        : '${_ordinal(row.position)} in the table',
                    style: context.caption,
                  ),
                ],
              ),
            ),
            if (row != null) FormDots(row.form),
          ],
        ),
      );
    }

    return Panel(
      key: const Key('form-panel'),
      title: 'Coming in',
      child: Column(
        children: [
          side(Side.home),
          Divider(color: p.line),
          side(Side.away),
        ],
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

/// The last five results as letters in discs. A win is filled, a draw is
/// outlined and a loss is quiet, so it reads without colour.
class FormDots extends StatelessWidget {
  const FormDots(this.form, {super.key, this.size = 20});

  final List<Outcome> form;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (form.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label:
          'Last ${form.length}: '
          '${form.map((o) => o.name).join(', ')}',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in form)
            Container(
              width: size,
              height: size,
              margin: const EdgeInsets.only(left: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: switch (o) {
                  Outcome.win => p.positive,
                  Outcome.draw => null,
                  Outcome.loss => p.plate,
                },
                border: o == Outcome.draw ? Border.all(color: p.muted) : null,
              ),
              child: Text(
                switch (o) {
                  Outcome.win => 'W',
                  Outcome.draw => 'D',
                  Outcome.loss => 'L',
                },
                style: TextStyle(
                  fontSize: size * .5,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: o == Outcome.win ? p.card : p.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The two sides compared, a row per measure: each value rolls and the bar
/// between them slides as the balance shifts.
class StatsTab extends StatelessWidget {
  const StatsTab(this.match, {super.key});

  final MatchSnapshot match;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = match;
    if (m.stage == MatchStage.upcoming) {
      return Panel(
        child: Text('The numbers start with the match.', style: context.body),
      );
    }
    final home = p.tint(m.home.crest.tint), away = p.tint(m.away.crest.tint);
    return Panel(
      key: const Key('stats-panel'),
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CrestBadge(m.home, size: 22),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(m.home.short, style: context.title)),
              Text(m.away.short, style: context.title),
              const SizedBox(width: Space.sm),
              CrestBadge(m.away, size: 22),
            ],
          ),
          const SizedBox(height: Space.sm),
          for (final s in m.stats)
            Padding(
              key: Key('stat-${s.label}'),
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Column(
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: RollingNumber(
                          s.text(Side.home),
                          alignment: Alignment.centerLeft,
                          highlight: p.accentInk,
                          style: context.figure.copyWith(
                            fontWeight: s.home >= s.away
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          s.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.caption,
                        ),
                      ),
                      SizedBox(
                        width: 64,
                        child: RollingNumber(
                          s.text(Side.away),
                          highlight: p.accentInk,
                          style: context.figure.copyWith(
                            fontWeight: s.away >= s.home
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: GrowBar(
                          value: s.share,
                          color: home,
                          fromRight: true,
                          height: 5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GrowBar(
                          value: 1 - s.share,
                          color: away,
                          height: 5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// One line of commentary: when, a mark for what kind of moment it was,
/// and what happened.
class FeedLine extends StatelessWidget {
  const FeedLine(
    this.item, {
    super.key,
    required this.match,
    this.dense = false,
  });

  final FeedItem item;
  final MatchSnapshot match;

  /// In a summary: tighter, without the card of its own.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = item;
    final team = f.side == null ? null : match.team(f.side!);
    final loud = f.major && f.kind != FeedKind.period;
    final (IconData? icon, Color fill, Color ink) = switch (f.kind) {
      FeedKind.score => (
        f.badge.isEmpty ? Icons.sports_score_rounded : null,
        loud ? p.accent : p.accentWash,
        loud ? p.onAccent : p.accentInk,
      ),
      FeedKind.wicket => (null, p.ink, p.paper),
      FeedKind.card => (
        Icons.style_rounded,
        f.major ? p.accent : p.accentWash,
        f.major ? p.onAccent : p.accentInk,
      ),
      FeedKind.change => (Icons.swap_vert_rounded, p.field, p.inkSoft),
      FeedKind.period => (Icons.timer_outlined, p.field, p.inkSoft),
      FeedKind.note => (null, p.field, p.inkSoft),
    };
    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 8 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                f.clock,
                maxLines: 1,
                overflow: TextOverflow.clip,
                softWrap: false,
                style: context.figure.copyWith(fontSize: 12, color: p.muted),
              ),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: icon != null
                ? Icon(icon, size: 15, color: ink)
                : Text(
                    f.badge,
                    style: TextStyle(
                      color: ink,
                      fontSize: f.badge.length > 1 ? 10.5 : 12.5,
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.title,
                  style: context.title.copyWith(
                    fontSize: 14,
                    fontWeight: f.major ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (f.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      team == null || dense
                          ? f.detail
                          : '${team.short}. ${f.detail}',
                      style: context.caption,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What a sport calls its third tab, and what goes in it.
String detailTabLabel(Sport sport) => switch (sport) {
  Sport.football => 'Line-ups',
  Sport.basketball => 'Box score',
  Sport.cricket => 'Scorecard',
};

Widget detailTab(MatchSnapshot m) => switch (m) {
  FootballSnapshot() => LineupsView(m),
  BasketballSnapshot() => BoxScoreView(m),
  CricketSnapshot() => ScorecardView(m),
  _ => const SizedBox.shrink(),
};

/// Both teams as a pair of buttons: the way from a match to either side.
class TeamsStrip extends StatelessWidget {
  const TeamsStrip(this.match, {super.key});

  final MatchSnapshot match;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        0,
        Space.gutter,
        Space.md,
      ),
      child: Row(
        children: [
          for (final s in Side.values) ...[
            if (s == Side.away) const SizedBox(width: Space.sm),
            Expanded(
              child: TextButton(
                key: Key('open-team-${s.name}'),
                onPressed: () => openTeam(context, match.team(s).id),
                style: TextButton.styleFrom(
                  foregroundColor: p.ink,
                  backgroundColor: p.card,
                  minimumSize: const Size(48, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CrestBadge(match.team(s), size: 20),
                    const SizedBox(width: Space.sm),
                    Flexible(
                      child: Text(
                        match.team(s).short,
                        style: context.title.copyWith(fontSize: 13.5),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
