import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/services/key_catalog.dart';
import 'package:keydui/ui/key_field.dart';

const catalog = KeyCatalog(['esc', 'escape', 'f4', 'home', 'left']);

Future<void> pumpField(
  WidgetTester tester, {
  required ValueChanged<String> onChanged,
  String? Function(String)? warningBuilder,
  ValueChanged<Set<Modifier>>? onModifiersCaptured,
  String value = '',
}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: KeyField(
          label: 'To',
          value: value,
          catalog: catalog,
          onChanged: onChanged,
          onModifiersCaptured: onModifiersCaptured,
          warningBuilder: warningBuilder,
        ),
      ),
    ));

void main() {
  testWidgets('typing filters the catalog and selecting reports the key',
      (tester) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.enterText(find.byType(TextField), 'f4');
    await tester.pumpAndSettle();
    await tester.tap(find.text('f4').last);
    await tester.pumpAndSettle();
    expect(picked, 'f4');
  });

  testWidgets('listen mode captures a keypress', (tester) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.tap(find.byIcon(Icons.headphones));
    await tester.pumpAndSettle();
    expect(find.text('Press a key…'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await tester.pumpAndSettle();
    expect(picked, 'f4');
    expect(find.text('Press a key…'), findsNothing);
  });

  testWidgets('cancel leaves listen mode without reporting a key',
      (tester) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.tap(find.byIcon(Icons.headphones));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Press a key…'), findsNothing);
  });

  testWidgets('a remapped capture offers the pre-remap key', (tester) async {
    final reported = <String>[];
    await pumpField(
      tester,
      onChanged: reported.add,
      warningBuilder: (key) => key == 'home' ? 'meta+left' : null,
    );
    await tester.tap(find.byIcon(Icons.headphones));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(find.text('keyd maps meta+left to this key'), findsOneWidget);
    await tester.tap(find.text('Use meta+left'));
    await tester.pumpAndSettle();
    expect(reported, ['home', 'meta+left']);
  });

  testWidgets('a modifier held alone is not a capture', (tester) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.tap(find.byIcon(Icons.headphones));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Press a key…'), findsOneWidget);
  });

  testWidgets('a held modifier is reported alongside the captured key',
      (tester) async {
    String? picked;
    Set<Modifier>? capturedModifiers;
    await pumpField(
      tester,
      onChanged: (v) => picked = v,
      onModifiersCaptured: (mods) => capturedModifiers = mods,
    );
    await tester.tap(find.byIcon(Icons.headphones));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.f4);
    await tester.pumpAndSettle();
    expect(picked, 'f4');
    expect(capturedModifiers, {Modifier.shift});
    await tester.sendKeyUpEvent(LogicalKeyboardKey.f4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  });

  testWidgets('escape while listening is captured, not treated as cancel',
      (tester) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.tap(find.byIcon(Icons.headphones));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(picked, 'esc');
    expect(find.text('Press a key…'), findsNothing);
  });
}
