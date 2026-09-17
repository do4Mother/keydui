import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/mapping_row.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/services/key_catalog.dart';
import 'package:keydui/ui/mapping_row_tile.dart';

const catalog = KeyCatalog(['esc', 'home', 'left']);
const row = MappingRow(
  modifiers: {Modifier.meta},
  fromKey: 'left',
  toKey: 'home',
);

void main() {
  testWidgets('renders modifiers and both keys', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MappingRowTile(
          row: row,
          catalog: catalog,
          onChanged: (_) {},
          onDelete: () {},
        ),
      ),
    ));
    expect(find.text('meta'), findsOneWidget);
    expect(find.text('shift'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'left'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'home'), findsOneWidget);
  });

  testWidgets('toggling a chip reports the new modifier set', (tester) async {
    MappingRow? updated;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MappingRowTile(
          row: row,
          catalog: catalog,
          onChanged: (r) => updated = r,
          onDelete: () {},
        ),
      ),
    ));
    await tester.tap(find.text('shift'));
    await tester.pumpAndSettle();
    expect(updated!.modifiers, {Modifier.meta, Modifier.shift});
  });

  testWidgets('delete fires', (tester) async {
    var deleted = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MappingRowTile(
          row: row,
          catalog: catalog,
          onChanged: (_) {},
          onDelete: () => deleted = true,
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(deleted, isTrue);
  });

  testWidgets(
      'a listen capture on the from-field applies the captured modifiers '
      'and the captured key together, so neither call clobbers the other',
      (tester) async {
    final updates = <MappingRow>[];
    const plainRow = MappingRow(modifiers: {}, fromKey: 'esc', toKey: 'home');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MappingRowTile(
          row: plainRow,
          catalog: catalog,
          onChanged: updates.add,
          onDelete: () {},
        ),
      ),
    ));

    // Both the from- and to-fields have a listen (headphones) button; the
    // from-field's is first.
    await tester.tap(find.byIcon(Icons.headphones).first);
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(updates, isNotEmpty);
    // Whatever the last row emitted to onChanged is, it must carry BOTH the
    // captured modifier and the captured key -- not just one of the two.
    expect(updates.last.modifiers, {Modifier.meta});
    expect(updates.last.fromKey, 'left');

    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  });

  testWidgets('the to-field accepts an action the catalog does not list',
      (tester) async {
    String? picked;
    const plainRow = MappingRow(modifiers: {}, fromKey: 'esc', toKey: 'home');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MappingRowTile(
          row: plainRow,
          catalog: catalog,
          onChanged: (r) => picked = r.toKey,
          onDelete: () {},
        ),
      ),
    ));

    final toField = find.widgetWithText(TextField, 'home');
    await tester.enterText(toField, 'S-home');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(picked, 'S-home');
    expect(
        find.text("keyd doesn't recognise this key name."), findsNothing);
  });
}
