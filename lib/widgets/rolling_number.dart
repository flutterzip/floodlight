import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../config/motion.dart';

/// A number whose digits roll over when it changes.
///
/// Built for a screen where twenty numbers can change in the same second
/// without anything else moving:
///
///  * Every digit sits in a cell as wide as the widest digit, so "111" and
///    "888" take the same room and nothing beside the number shifts.
///  * A change repaints this widget only. The animation drives a render
///    object directly: no rebuild, no layout, and a repaint boundary keeps
///    the rest of the screen out of it.
///  * Only the digits that differ move. The outgoing and the incoming digit
///    are both drawn and slid one line, inside a clip the size of the cell.
///    Columns start a beat apart, right to left.
///  * Glyphs are laid out once per style and shared by every number on the
///    screen.
///
/// Anything that is not a digit ("/", ".", ":") is drawn where it falls.
/// With reduce motion on, the new value simply appears.
class RollingNumber extends StatefulWidget {
  const RollingNumber(
    this.text, {
    super.key,
    required this.style,
    this.highlight,
    this.reserve = '',
    this.alignment = Alignment.centerRight,
    this.semanticsLabel,
  });

  final String text;
  final TextStyle style;

  /// The colour a digit arrives in before it settles to the style's own.
  final Color? highlight;

  /// The widest value expected, such as "000/0". Room for it is kept even
  /// while the value is shorter, so a score reaching three figures does not
  /// push its neighbours.
  final String reserve;

  /// Where the digits sit when there is room to spare.
  final Alignment alignment;
  final String? semanticsLabel;

  @override
  State<RollingNumber> createState() => _RollingNumberState();
}

class _RollingNumberState extends State<RollingNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  late String _from;

  @override
  void initState() {
    super.initState();
    _from = widget.text;
    _progress = AnimationController(
      vsync: this,
      duration: Motion.roll + Motion.flash,
      value: 1,
    );
  }

  @override
  void didUpdateWidget(RollingNumber old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    _from = old.text;
    if (Motion.reduced(context)) {
      _progress.value = 1;
    } else {
      _progress.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return Semantics(
      label: widget.semanticsLabel ?? widget.text,
      child: RepaintBoundary(
        child: _Roll(
          from: _from,
          to: widget.text,
          reserve: widget.reserve,
          alignment: widget.alignment,
          progress: _progress,
          glyphs: GlyphSet.of(style, scaler),
          hot: widget.highlight == null
              ? null
              : GlyphSet.of(style.copyWith(color: widget.highlight), scaler),
        ),
      ),
    );
  }
}

/// The glyphs of one text style, laid out once and shared.
class GlyphSet {
  GlyphSet._(this._style, this._scaler) {
    var widest = 0.0;
    for (var d = 0; d < 10; d++) {
      widest = math.max(widest, painter('$d').width);
    }
    digitWidth = widest;
    final zero = painter('0');
    height = zero.height;
    baseline = zero.computeDistanceToActualBaseline(TextBaseline.alphabetic);
  }

  factory GlyphSet.of(TextStyle style, TextScaler scaler) {
    final key = (style, scaler);
    final hit = _sets[key];
    if (hit != null) return hit;
    // Styles are few and long-lived. If something is generating them
    // without end, forget the old sets rather than grow for ever. They are
    // only forgotten, never disposed: a number on screen still holds its
    // set and goes on painting with it, and a set nobody holds is collected.
    if (_sets.length >= _most) _sets.clear();
    return _sets[key] = GlyphSet._(style, scaler);
  }

  static const _most = 256;
  static final _sets = <(TextStyle, TextScaler), GlyphSet>{};

  final TextStyle _style;
  final TextScaler _scaler;
  final _painters = <String, TextPainter>{};

  /// The width of a digit's cell: the widest of the ten.
  late final double digitWidth;
  late final double height;
  late final double baseline;

  TextPainter painter(String char) => _painters.putIfAbsent(
    char,
    () => TextPainter(
      text: TextSpan(text: char, style: _style),
      textDirection: TextDirection.ltr,
      textScaler: _scaler,
      maxLines: 1,
    )..layout(),
  );

  static bool isDigit(String char) {
    final c = char.codeUnitAt(0);
    return c >= 0x30 && c <= 0x39;
  }

  double widthOf(String char) =>
      isDigit(char) ? digitWidth : painter(char).width;

  double measure(String text) {
    var w = 0.0;
    for (var i = 0; i < text.length; i++) {
      w += widthOf(text[i]);
    }
    return w;
  }
}

class _Roll extends LeafRenderObjectWidget {
  const _Roll({
    required this.from,
    required this.to,
    required this.reserve,
    required this.alignment,
    required this.progress,
    required this.glyphs,
    required this.hot,
  });

  final String from;
  final String to;
  final String reserve;
  final Alignment alignment;
  final Animation<double> progress;
  final GlyphSet glyphs;
  final GlyphSet? hot;

  @override
  RenderRollingNumber createRenderObject(BuildContext context) =>
      RenderRollingNumber(
        from: from,
        to: to,
        reserve: reserve,
        alignment: alignment,
        progress: progress,
        glyphs: glyphs,
        hot: hot,
      );

  @override
  void updateRenderObject(BuildContext context, RenderRollingNumber r) {
    r
      ..from = from
      ..to = to
      ..reserve = reserve
      ..alignment = alignment
      ..progress = progress
      ..glyphs = glyphs
      ..hot = hot;
  }
}

/// Lays out to the width of the value (or the reserve, if wider) and paints
/// the roll. The animation only ever asks for a repaint.
class RenderRollingNumber extends RenderBox {
  RenderRollingNumber({
    required String from,
    required String to,
    required String reserve,
    required Alignment alignment,
    required Animation<double> progress,
    required GlyphSet glyphs,
    required GlyphSet? hot,
  }) : _from = from,
       _to = to,
       _reserve = reserve,
       _alignment = alignment,
       _progress = progress,
       _glyphs = glyphs,
       _hot = hot;

  /// The share of the animation the roll itself takes. The rest is the
  /// highlight fading.
  static final rollShare =
      Motion.roll.inMicroseconds / (Motion.roll + Motion.flash).inMicroseconds;

  String _from;
  set from(String v) {
    if (v == _from) return;
    _from = v;
    markNeedsPaint();
  }

  String _to;
  String get to => _to;
  set to(String v) {
    if (v == _to) return;
    final resize = _glyphs.measure(v) != _glyphs.measure(_to);
    _to = v;
    resize ? markNeedsLayout() : markNeedsPaint();
  }

  String _reserve;
  set reserve(String v) {
    if (v == _reserve) return;
    _reserve = v;
    markNeedsLayout();
  }

  Alignment _alignment;
  set alignment(Alignment v) {
    if (v == _alignment) return;
    _alignment = v;
    markNeedsPaint();
  }

  GlyphSet _glyphs;
  set glyphs(GlyphSet v) {
    if (identical(v, _glyphs)) return;
    _glyphs = v;
    markNeedsLayout();
  }

  GlyphSet? _hot;
  set hot(GlyphSet? v) {
    if (identical(v, _hot)) return;
    _hot = v;
    markNeedsPaint();
  }

  Animation<double> _progress;
  set progress(Animation<double> v) {
    if (identical(v, _progress)) return;
    if (attached) _progress.removeListener(markNeedsPaint);
    _progress = v;
    if (attached) _progress.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _progress.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _progress.removeListener(markNeedsPaint);
    super.detach();
  }

  double get _width =>
      math.max(_glyphs.measure(_to), _glyphs.measure(_reserve));

  @override
  double computeMinIntrinsicWidth(double height) => _width;

  @override
  double computeMaxIntrinsicWidth(double height) => _width;

  @override
  double computeMinIntrinsicHeight(double width) => _glyphs.height;

  @override
  double computeMaxIntrinsicHeight(double width) => _glyphs.height;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _glyphs.baseline;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(Size(_width, _glyphs.height));

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  bool hitTestSelf(Offset position) => false;

  /// Whether the value went up, judged on its digits alone.
  bool get _rising {
    int? digits(String s) => int.tryParse(s.replaceAll(RegExp(r'\D'), ''));
    final a = digits(_from), b = digits(_to);
    return a == null || b == null || b >= a;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final g = _glyphs;
    final p = _progress.value;
    final rolling = p < 1 && _from != _to;
    final dir = _rising ? 1.0 : -1.0;
    final content = g.measure(_to);
    // Where the value's right edge falls inside the box.
    final right =
        offset.dx + (size.width - content) * (_alignment.x + 1) / 2 + content;
    final top = offset.dy + (size.height - g.height) * (_alignment.y + 1) / 2;
    final glow = _hot == null ? 0.0 : math.pow(1 - p, 1.6).toDouble();

    var x = right;
    for (var r = 0; r < _to.length; r++) {
      final char = _to[_to.length - 1 - r];
      final was = r < _from.length ? _from[_from.length - 1 - r] : null;
      final w = g.widthOf(char);
      x -= w;
      final glyph = g.painter(char);
      final at = Offset(x + (w - glyph.width) / 2, top);
      if (!rolling || was == char) {
        glyph.paint(canvas, at);
        continue;
      }
      // Each column starts a beat after the one to its right.
      final t = Motion.settle.transform(
        ((p / rollShare - r * Motion.rollStagger) /
                (1 - math.min(_to.length - 1, 4) * Motion.rollStagger))
            .clamp(0.0, 1.0),
      );
      final cell = Rect.fromLTWH(x, top, w, g.height);
      canvas
        ..save()
        ..clipRect(cell);
      if (was != null && t < 1) {
        final old = g.painter(was);
        old.paint(
          canvas,
          Offset(x + (w - old.width) / 2, top - dir * t * g.height),
        );
      }
      final arriving = at.translate(0, dir * (1 - t) * g.height);
      glyph.paint(canvas, arriving);
      if (glow > .02) {
        canvas.saveLayer(cell, Paint()..color = Color.fromRGBO(0, 0, 0, glow));
        _hot!.painter(char).paint(canvas, arriving);
        canvas.restore();
      }
      canvas.restore();
    }
  }
}
