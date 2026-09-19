import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/mapping_row.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/models/remap_warning.dart';
import 'package:keydui/services/key_catalog.dart';
import 'package:keydui/ui/chord_field.dart';
import 'package:keydui/ui/mapping_row_tile.dart';

const catalog = KeyCatalog(['esc', 'f4', 'home', 'left']);
const row = MappingRow(
  modifiers: {Modifier.meta},
  fromKey: 'left',
  toKey: 'home',
);

Future<List<MappingRow>> pumpTile(
  WidgetTester tester, {
  MappingRow row = row,
  VoidCallback? onDelete,
  RemapWarning? Function(String)? warningBuilder,
}) async {
  final updates = <MappingRow>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MappingRowTile(
          row: row,
          catalog: catalog,
          warningBuilder: warningBuilder,
          onChanged: updates.add,
          onDelete: onDelete ?? () {},
        ),
      ),
    ),
  );
  return updates;
}

/// The two halves of the tile carry identically-labelled chips, so a chip
/// finder has to say which side it means.
Finder chipOn(String side, String label) => find.descendant(
  of: find.widgetWithText(ChordField, side),
  matching: find.widgetWithText(FilterChip, label),
);

Finder keyFieldOn(String side) => find.descendant(
  of: find.widgetWithText(ChordField, side),
  matching: find.byType(TextField),
);

/// A tile wired to its own state, the way the app wires it: whatever the tile
/// reports flows straight back in as its next row. A chip that does not stick
/// here does not stick in the app.
Future<List<MappingRow>> pumpLiveTile(
  WidgetTester tester, {
  MappingRow row = row,
}) async {
  final updates = <MappingRow>[];
  var current = row;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => MappingRowTile(
            row: current,
            catalog: catalog,
            onChanged: (next) {
              updates.add(next);
              setState(() => current = next);
            },
            onDelete: () {},
          ),
        ),
      ),
    ),
  );
  return updates;
}

void main() {
  testWidgets('renders both halves in keyboard names', (tester) async {
    await pumpTile(tester);
    expect(find.widgetWithText(TextField, 'Left Arrow'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Home'), findsOneWidget);
    // Every modifier is offered on both sides now, under its keyboard name.
    expect(find.widgetWithText(FilterChip, 'Super'), findsNWidgets(2));
    expect(find.widgetWithText(FilterChip, 'Ctrl'), findsNWidgets(2));
    expect(find.text('meta'), findsNothing);
  });

  testWidgets('toggling a trigger chip reports the new modifier set', (
    tester,
  ) async {
    final updates = await pumpTile(tester);
    await tester.tap(chipOn('Press', 'Shift'));
    await tester.pumpAndSettle();
    expect(updates.single.modifiers, {Modifier.meta, Modifier.shift});
    expect(updates.single.fromKey, 'left');
  });

  testWidgets('delete fires', (tester) async {
    var deleted = false;
    await pumpTile(tester, onDelete: () => deleted = true);
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(deleted, isTrue);
  });

  group('the action side', () {
    testWidgets('decodes a keyd prefix into chips', (tester) async {
      // The whole point of the exercise: `S-home` is Shift+Home, and the row
      // says so instead of making the user decode the prefix.
      await pumpTile(
        tester,
        row: const MappingRow(modifiers: {}, fromKey: 'esc', toKey: 'S-home'),
      );
      final shift = tester.widget<FilterChip>(chipOn('Send', 'Shift'));
      expect(shift.selected, isTrue);
      expect(
        tester.widget<FilterChip>(chipOn('Press', 'Shift')).selected,
        isFalse,
      );
      expect(find.widgetWithText(TextField, 'Home'), findsOneWidget);
      expect(find.textContaining('Shift + Home'), findsOneWidget);
      expect(find.textContaining('writes S-home'), findsOneWidget);
    });

    testWidgets('toggling a chip rewrites the action in keyd notation', (
      tester,
    ) async {
      final updates = await pumpTile(
        tester,
        row: const MappingRow(modifiers: {}, fromKey: 'esc', toKey: 'f4'),
      );
      await tester.tap(chipOn('Send', 'Ctrl'));
      await tester.pumpAndSettle();
      expect(updates.single.toKey, 'C-f4');
    });

    testWidgets('a capture builds ctrl+alt+f4 without typing a prefix', (
      tester,
    ) async {
      final updates = await pumpTile(
        tester,
        row: const MappingRow(modifiers: {}, fromKey: 'esc', toKey: ''),
      );
      // The second capture button belongs to the action side.
      await tester.tap(find.byIcon(Icons.keyboard).last);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.f4);
      await tester.pumpAndSettle();

      expect(updates.last.toKey, 'C-A-f4');
      expect(updates.last.fromKey, 'esc');

      await tester.sendKeyUpEvent(LogicalKeyboardKey.f4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    });

    testWidgets('a prefix typed by hand still works and merges with chips', (
      tester,
    ) async {
      final updates = await pumpTile(
        tester,
        row: const MappingRow(modifiers: {}, fromKey: 'esc', toKey: 'C-f4'),
      );
      await tester.enterText(keyFieldOn('Send'), 'S-home');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(updates.last.toKey, 'C-S-home');
    });

    testWidgets('an expression the chips cannot show stays raw text', (
      tester,
    ) async {
      await pumpTile(
        tester,
        row: const MappingRow(
          modifiers: {},
          fromKey: 'esc',
          toKey: 'macro(a b)',
        ),
      );
      expect(find.widgetWithText(ChordField, 'Send'), findsNothing);
      expect(find.widgetWithText(TextField, 'macro(a b)'), findsOneWidget);
      expect(
        find.text('This is a keyd expression, so it stays as typed.'),
        findsOneWidget,
      );
    });

    testWidgets('an expression can be edited, and stays an expression', (
      tester,
    ) async {
      final updates = await pumpTile(
        tester,
        row: const MappingRow(
          modifiers: {},
          fromKey: 'esc',
          toKey: 'macro(a b)',
        ),
      );
      await tester.enterText(find.byType(TextField).last, 'layer(nav)');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(updates.last.toKey, 'layer(nav)');
    });

    testWidgets('leaving the expression behind restores the chips', (
      tester,
    ) async {
      final updates = await pumpTile(
        tester,
        row: const MappingRow(
          modifiers: {},
          fromKey: 'esc',
          toKey: 'macro(a b)',
        ),
      );
      await tester.tap(find.text('Use keys instead'));
      await tester.pumpAndSettle();
      expect(updates.single.toKey, '');
    });

    testWidgets('typing an expression into the key field switches modes', (
      tester,
    ) async {
      final updates = await pumpTile(
        tester,
        row: const MappingRow(modifiers: {}, fromKey: 'esc', toKey: 'C-f4'),
      );
      await tester.enterText(keyFieldOn('Send'), 'macro(a b)');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      // `C-macro(a b)` is not valid keyd, so the chips are dropped rather
      // than stapled onto the expression.
      expect(updates.last.toKey, 'macro(a b)');
    });
  });

  testWidgets('a listen capture on the trigger applies the captured modifiers '
      'and the captured key together, so neither call clobbers the other', (
    tester,
  ) async {
    final updates = await pumpTile(
      tester,
      row: const MappingRow(modifiers: {}, fromKey: 'esc', toKey: 'home'),
    );
    await tester.tap(find.byIcon(Icons.keyboard).first);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    expect(updates.last.modifiers, {Modifier.meta});
    expect(updates.last.fromKey, 'left');
    expect(updates.last.toKey, 'home');

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  });

  testWidgets(
    'accepting a remap warning moves the modifier half onto the chips and '
    'only the bare key into the trigger key field',
    (tester) async {
      final updates = await pumpTile(
        tester,
        row: const MappingRow(modifiers: {}, fromKey: '', toKey: 'pageup'),
        warningBuilder: (key) => key == 'home'
            ? const RemapWarning(modifiers: {Modifier.meta}, fromKey: 'left')
            : null,
      );

      await tester.tap(find.byIcon(Icons.keyboard).first);
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
      // `meta` belongs to the section header, so it must reach the row's
      // modifier set -- not the key name, which would serialize to
      // `meta+left = pageup` inside `[main]` and be rejected by keyd.
      expect(updates.single.modifiers, {Modifier.meta});
      expect(updates.single.fromKey, 'left');
      expect(updates.single.toKey, 'pageup');
    },
  );

  group('chips on a half that has no key yet', () {
    const empty = MappingRow(modifiers: {}, fromKey: '', toKey: '');

    testWidgets('a trigger chip stays selected', (tester) async {
      await pumpLiveTile(tester, row: empty);
      await tester.tap(chipOn('Press', 'Ctrl'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilterChip>(chipOn('Press', 'Ctrl')).selected,
        isTrue,
      );
    });

    testWidgets('an action chip stays selected', (tester) async {
      // An action with no key has no keyd text to hold its modifiers -- `C-`
      // alone is not a mapping -- so the chips are remembered here until a
      // key arrives to carry them.
      await pumpLiveTile(tester, row: empty);
      await tester.tap(chipOn('Send', 'Ctrl'));
      await tester.tap(chipOn('Send', 'Super'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilterChip>(chipOn('Send', 'Ctrl')).selected,
        isTrue,
      );
      expect(
        tester.widget<FilterChip>(chipOn('Send', 'Super')).selected,
        isTrue,
      );
    });

    testWidgets('an action chip un-toggles again', (tester) async {
      await pumpLiveTile(tester, row: empty);
      await tester.tap(chipOn('Send', 'Ctrl'));
      await tester.pumpAndSettle();
      await tester.tap(chipOn('Send', 'Ctrl'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilterChip>(chipOn('Send', 'Ctrl')).selected,
        isFalse,
      );
    });

    testWidgets('the remembered chips reach the key typed next', (
      tester,
    ) async {
      final updates = await pumpLiveTile(tester, row: empty);
      await tester.tap(chipOn('Send', 'Ctrl'));
      await tester.pumpAndSettle();
      await tester.enterText(keyFieldOn('Send'), 'f4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(updates.last.toKey, 'C-f4');
    });

    testWidgets('a capture replaces the remembered chips', (tester) async {
      // A capture is the whole chord, so what was held during it wins over
      // chips clicked beforehand -- here nothing was held, so Shift goes.
      final updates = await pumpLiveTile(tester, row: empty);
      await tester.tap(chipOn('Send', 'Shift'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.keyboard).last);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(updates.last.toKey, 'home');
      expect(
        tester.widget<FilterChip>(chipOn('Send', 'Shift')).selected,
        isFalse,
      );
    });
  });
}
