import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Every colour in the app is defined in this file.
//
// To re-skin Floodlight, edit [Palette.light] and [Palette.dark] below. Every
// screen, sheet and button, the splash, the glass tab bar, the scoreboard,
// the pitch, the charts, the team crests and the logo itself read their
// colours from here through `context.palette`; nothing else in lib/
// hard-codes a colour (a test enforces it). `tool/make_mark.py` reads this
// file too, so the app icon follows the same values.
//
// One thing is deliberately not here: the Apple and Google sign-in buttons
// (lib/widgets/social_buttons.dart), whose colours are fixed by their brand
// guidelines.
//
// The system: chalk paper, night ink, and exactly one accent, the red of a
// live light. The scoreboard is a block of night in both modes, the way a
// stadium board is dark at noon. Ink is never pure black and paper is never
// pure white.
//
// Team crests are the one place a second hue appears, because a team has to
// be told from its opponent at a glance. They draw from [teamTints], a
// short ramp of quiet colours kept here. Seed data stores an index into it,
// never a colour.
// ---------------------------------------------------------------------------

@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.paper,
    required this.card,
    required this.plate,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.line,
    required this.field,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.accentInk,
    required this.onAccent,
    required this.accentWash,
    required this.error,
    required this.positive,
    required this.shadow,
    required this.mesh,
    required this.glassTint,
    required this.scrim,
    required this.onIsland,
    required this.board,
    required this.boardRaised,
    required this.onBoard,
    required this.boardMuted,
    required this.boardLine,
    required this.pitch,
    required this.pitchLine,
    required this.teamTints,
    required this.onTeam,
  });

  /// The page ground.
  final Color paper;

  /// Raised surfaces: cards, sheets.
  final Color card;

  /// A quiet fill: table header rows, skeletons, an unfilled bar.
  final Color plate;

  /// Primary type and icons.
  final Color ink;

  /// Body copy.
  final Color inkSoft;

  /// Captions, hints, inactive icons.
  final Color muted;

  /// Hairlines and dividers.
  final Color line;

  /// The fill of a text field or an unselected chip at rest.
  final Color field;

  /// The main button, and type on top of it.
  final Color primary;
  final Color onPrimary;

  /// The one accent: live, selected, the number that just changed.
  final Color accent;

  /// The accent when it is type or a fine icon on [paper]: the same red,
  /// deep enough to read.
  final Color accentInk;

  /// Type and icons on top of [accent].
  final Color onAccent;

  /// A pale tint of the accent: a cell that just changed, a selected chip.
  final Color accentWash;

  /// Errors: a brick neighbour of the accent, not its opposite.
  final Color error;

  /// A win, a pick that came in, a rate that is ahead.
  final Color positive;

  /// Soft shadows under cards.
  final Color shadow;

  /// The four colours of the splash and sign-in mesh gradient.
  final List<Color> mesh;

  /// The tint of the glass tab bar.
  final Color glassTint;

  /// The dim behind a sheet.
  final Color scrim;

  /// Type on the black live pill.
  final Color onIsland;

  /// The scoreboard: its ground, a raised panel on it, its type, its quiet
  /// type and its hairlines. Dark in both modes.
  final Color board;
  final Color boardRaised;
  final Color onBoard;
  final Color boardMuted;
  final Color boardLine;

  /// The drawn football pitch and its markings.
  final Color pitch;
  final Color pitchLine;

  /// The crest colours. A team's seed row stores an index into this list.
  final List<Color> teamTints;

  /// Line work and numbers on top of a team tint.
  final Color onTeam;

  static const _tints = [
    Color(0xFF27477A), // harbour blue
    Color(0xFF9C2F3A), // claret
    Color(0xFF2C6B52), // pine
    Color(0xFFC08A2B), // old gold
    Color(0xFF5B4590), // plum
    Color(0xFF1F7C86), // teal
    Color(0xFF4A5462), // slate
    Color(0xFFC25B2A), // rust
  ];

  static const light = Palette(
    paper: Color(0xFFF3F2EE),
    card: Color(0xFFFCFBF9),
    plate: Color(0xFFE7E5DF),
    ink: Color(0xFF14171D),
    inkSoft: Color(0xFF3C414B),
    muted: Color(0xFF7C818B),
    line: Color(0xFFE1DFD8),
    field: Color(0xFFEAE8E2),
    primary: Color(0xFF14171D),
    onPrimary: Color(0xFFF7F5F1),
    accent: Color(0xFFE5452B),
    accentInk: Color(0xFFC2331B),
    onAccent: Color(0xFFFFF7F3),
    accentWash: Color(0xFFFBE4DD),
    error: Color(0xFFA8362A),
    positive: Color(0xFF1F7A55),
    shadow: Color(0x2414171D),
    mesh: [
      Color(0xFFF3F2EE),
      Color(0xFFF6D9CF),
      Color(0xFFD9DEE8),
      Color(0xFFFBE4DD),
    ],
    glassTint: Color(0x8A14171D),
    scrim: Color(0x5514171D),
    onIsland: Color(0xFFF7F5F1),
    board: Color(0xFF12151B),
    boardRaised: Color(0xFF1C2029),
    onBoard: Color(0xFFF7F5F1),
    boardMuted: Color(0xFF9AA0AC),
    boardLine: Color(0xFF2A2F3A),
    pitch: Color(0xFF1F5C44),
    pitchLine: Color(0x8CF7F5F1),
    teamTints: _tints,
    onTeam: Color(0xFFF7F5F1),
  );

  static const dark = Palette(
    paper: Color(0xFF0B0D11),
    card: Color(0xFF14171D),
    plate: Color(0xFF1E222B),
    ink: Color(0xFFF1EFEA),
    inkSoft: Color(0xFFC5C8CF),
    muted: Color(0xFF8B909B),
    line: Color(0xFF232832),
    field: Color(0xFF191D25),
    primary: Color(0xFFFF5B3F),
    onPrimary: Color(0xFF14090A),
    accent: Color(0xFFFF5B3F),
    accentInk: Color(0xFFFF7A62),
    onAccent: Color(0xFF14090A),
    accentWash: Color(0xFF34191A),
    error: Color(0xFFEF8573),
    positive: Color(0xFF62C79A),
    shadow: Color(0x66000000),
    mesh: [
      Color(0xFF0B0D11),
      Color(0xFF34191A),
      Color(0xFF16202F),
      Color(0xFF12151B),
    ],
    glassTint: Color(0x8A05060A),
    scrim: Color(0x99000000),
    onIsland: Color(0xFFF7F5F1),
    board: Color(0xFF14171D),
    boardRaised: Color(0xFF1E222B),
    onBoard: Color(0xFFF7F5F1),
    boardMuted: Color(0xFF9AA0AC),
    boardLine: Color(0xFF2C313C),
    pitch: Color(0xFF184936),
    pitchLine: Color(0x80F7F5F1),
    teamTints: _tints,
    onTeam: Color(0xFFF7F5F1),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).extension<Palette>()!;

  /// The crest colour at [index], wrapping, so a seed row can never point
  /// outside the ramp.
  Color tint(int index) => teamTints[index % teamTints.length];

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    List<Color> ll(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length; i++) l(a[i], b[i]),
    ];
    return Palette(
      paper: l(paper, other.paper),
      card: l(card, other.card),
      plate: l(plate, other.plate),
      ink: l(ink, other.ink),
      inkSoft: l(inkSoft, other.inkSoft),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      field: l(field, other.field),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      accent: l(accent, other.accent),
      accentInk: l(accentInk, other.accentInk),
      onAccent: l(onAccent, other.onAccent),
      accentWash: l(accentWash, other.accentWash),
      error: l(error, other.error),
      positive: l(positive, other.positive),
      shadow: l(shadow, other.shadow),
      mesh: ll(mesh, other.mesh),
      glassTint: l(glassTint, other.glassTint),
      scrim: l(scrim, other.scrim),
      onIsland: l(onIsland, other.onIsland),
      board: l(board, other.board),
      boardRaised: l(boardRaised, other.boardRaised),
      onBoard: l(onBoard, other.onBoard),
      boardMuted: l(boardMuted, other.boardMuted),
      boardLine: l(boardLine, other.boardLine),
      pitch: l(pitch, other.pitch),
      pitchLine: l(pitchLine, other.pitchLine),
      teamTints: ll(teamTints, other.teamTints),
      onTeam: l(onTeam, other.onTeam),
    );
  }
}
