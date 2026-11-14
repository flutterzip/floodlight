import 'package:floodlight/config/motion.dart';
import 'package:floodlight/widgets/rolling_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(
  fontSize: 20,
  fontFeatures: [FontFeature.tabularFigures()],
);

Widget _host(String text, {bool calm = false, String reserve = ''}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: calm),
        child: Center(
          child: RollingNumber(
            text,
            style: _style,
            reserve: reserve,
            highlight: const Color.fromARGB(255, 200, 40, 20),
          ),
        ),
      ),
    );

void main() {
  final roll = find.byType(RollingNumber);
  RenderRollingNumber render(WidgetTester t) => t.renderObject(
    find.byWidgetPredicate((w) => w is LeafRenderObjectWidget),
  );

  testWidgets('a digit changing does not move the box', (t) async {
    await t.pumpWidget(_host('111'));
    final before = t.getSize(roll);
    await t.pumpWidget(_host('888'));
    await t.pump(const Duration(milliseconds: 100));
    expect(t.getSize(roll), before);
    await t.pumpAndSettle();
    expect(t.getSize(roll), before);
  });

  testWidgets('room is kept for the widest value expected', (t) async {
    await t.pumpWidget(_host('9', reserve: '000/0'));
    final small = t.getSize(roll);
    await t.pumpWidget(_host('164/5', reserve: '000/0'));
    await t.pumpAndSettle();
    expect(t.getSize(roll), small);
  });

  testWidgets('rolling asks for paint, never for layout or a rebuild', (
    t,
  ) async {
    await t.pumpWidget(_host('41'));
    await t.pumpWidget(_host('42'));
    await t.pump();
    var layouts = 0;
    final r = render(t);
    // A frame in the middle of the roll: the box must stay laid out.
    await t.pump(const Duration(milliseconds: 120));
    expect(r.debugNeedsLayout, isFalse);
    layouts += r.debugNeedsLayout ? 1 : 0;
    await t.pump(const Duration(milliseconds: 120));
    expect(layouts, 0);
    expect(t.hasRunningAnimations, isTrue);
    await t.pumpAndSettle();
    expect(t.hasRunningAnimations, isFalse);
    expect(r.to, '42');
  });

  testWidgets('settles in the time the motion config gives it', (t) async {
    await t.pumpWidget(_host('7'));
    await t.pumpWidget(_host('8'));
    await t.pump();
    await t.pump(Motion.roll + Motion.flash - const Duration(milliseconds: 30));
    expect(t.hasRunningAnimations, isTrue);
    await t.pump(const Duration(milliseconds: 60));
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('with reduce motion the new value simply appears', (t) async {
    await t.pumpWidget(_host('7', calm: true));
    await t.pumpWidget(_host('8', calm: true));
    await t.pump();
    expect(t.hasRunningAnimations, isFalse);
  });

  testWidgets('a screen reader hears the value, not its digits', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(_host('164/5'));
    expect(t.getSemantics(roll).label, '164/5');
    handle.dispose();
  });

  testWidgets('it has a baseline, so it lines up beside text', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              RollingNumber('12', style: _style),
              Text(' runs', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    final number = t.getRect(roll), words = t.getRect(find.text(' runs'));
    // The smaller text sits lower in its own box to share the baseline.
    expect(words.top, greaterThan(number.top));
  });

  test('glyphs are laid out once per style and shared', () {
    final a = GlyphSet.of(_style, TextScaler.noScaling);
    final b = GlyphSet.of(_style, TextScaler.noScaling);
    expect(identical(a, b), isTrue);
    expect(identical(a.painter('4'), b.painter('4')), isTrue);
    // Every digit gets the same cell.
    expect(a.widthOf('1'), a.widthOf('8'));
    expect(a.measure('111'), a.measure('888'));
  });
}
