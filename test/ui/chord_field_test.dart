import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/models/remap_warning.dart';
import 'package:keydui/services/key_catalog.dart';
import 'package:keydui/ui/chord_field.dart';

const catalog = KeyCatalog(['esc', 'f4', 'home', 'left', 'pageup']);

typedef Chord = ({Set<Modifier> modifiers, String key});

Future<List<Chord>> pumpChord(
  WidgetTester tester, {
  Set<Modifier> modifiers = const {},
  String keyName = '',
  String? footnote,
  RemapWarning? Function(String)? warningBuilder,
}) async {
  final updates = <Chord>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChordField(
          label: 'From',
          modifiers: modifiers,
          keyName: keyName,
          catalog: catalog,
          footnote: footnote,
          warningBuilder: warningBuilder,
          onChanged: (mods, key) => updates.add((modifiers: mods, key: key)),
        ),
      ),
    ),
  );
  return updates;
}

void main() {
  testWidgets('shows keyboard names, not keyd names', (tester) async {
    await pumpChord(
      tester,
      modifiers: const {Modifier.meta},
      keyName: 'pageup',
    );
    expect(find.text('Ctrl'), findsOneWidget);
    expect(find.text('Super'), findsOneWidget);
    expect(find.text('meta'), findsNothing);
    expect(find.widgetWithText(TextField, 'Page Up'), findsOneWidget);
  });

  testWidgets('a footnote shows what will be written to the config', (
    tester,
  ) async {
    await pumpChord(tester, footnote: 'writes C-A-f4');
    expect(find.text('writes C-A-f4'), findsOneWidget);
  });

  testWidgets('toggling a chip reports the new chord, key included', (
    tester,
  ) async {
    final updates = await pumpChord(
      tester,
      modifiers: const {Modifier.meta},
      keyName: 'left',
    );
    await tester.tap(find.text('Ctrl'));
    await tester.pumpAndSettle();
    expect(updates, hasLength(1));
    expect(updates.single.modifiers, {Modifier.meta, Modifier.control});
    expect(updates.single.key, 'left');
  });

  testWidgets('un-toggling a chip drops that modifier', (tester) async {
    final updates = await pumpChord(
      tester,
      modifiers: const {Modifier.meta, Modifier.shift},
      keyName: 'left',
    );
    await tester.tap(find.text('Shift'));
    await tester.pumpAndSettle();
    expect(updates.single.modifiers, {Modifier.meta});
  });

  testWidgets('a key typed as a display label is reported as a keyd name', (
    tester,
  ) async {
    final updates = await pumpChord(tester, modifiers: const {Modifier.alt});
    await tester.enterText(find.byType(TextField), 'Page Up');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    // Submitting also accepts the highlighted autocomplete option, so the
    // same chord may be reported twice; what matters is that every report
    // agrees and carries the keyd name, not the label that was typed.
    expect(updates, isNotEmpty);
    expect(updates.every((u) => u.key == 'pageup'), isTrue);
    expect(updates.last.modifiers, {Modifier.alt});
  });

  testWidgets('searching by display label finds the key', (tester) async {
    final updates = await pumpChord(tester);
    await tester.enterText(find.byType(TextField), 'page u');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Page Up').last);
    await tester.pumpAndSettle();
    expect(updates.single.key, 'pageup');
  });

  testWidgets(
    'a capture reports the held modifiers and the key in one update',
    (tester) async {
      final updates = await pumpChord(tester);
      await tester.tap(find.byIcon(Icons.keyboard));
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f4);
      await tester.pumpAndSettle();

      // Ctrl+Alt+F4 is one chord, so it must arrive as one update carrying
      // both halves -- a second update derived from the pre-capture chord
      // would drop whichever half the first one set.
      expect(updates, hasLength(1));
      expect(updates.single.modifiers, {Modifier.control, Modifier.alt});
      expect(updates.single.key, 'f4');

      await tester.sendKeyUpEvent(LogicalKeyboardKey.f4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    },
  );

  testWidgets('a capture with no modifiers held clears the chips', (
    tester,
  ) async {
    final updates = await pumpChord(
      tester,
      modifiers: const {Modifier.meta},
      keyName: 'left',
    );
    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await tester.pumpAndSettle();
    expect(updates.single.modifiers, isEmpty);
    expect(updates.single.key, 'f4');
  });

  testWidgets(
    'a remap warning reads in keyboard names and applies as a chord',
    (tester) async {
      final updates = await pumpChord(
        tester,
        warningBuilder: (key) => key == 'home'
            ? const RemapWarning(modifiers: {Modifier.meta}, fromKey: 'left')
            : null,
      );
      await tester.tap(find.byIcon(Icons.keyboard));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(
        find.text('keyd maps Super + Left Arrow to this key'),
        findsOneWidget,
      );

      updates.clear();
      await tester.tap(find.text('Use Super + Left Arrow'));
      await tester.pumpAndSettle();
      expect(updates, hasLength(1));
      expect(updates.single.modifiers, {Modifier.meta});
      expect(updates.single.key, 'left');
    },
  );
}
