import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/services/apply_service.dart';
import 'package:keydui/services/key_catalog.dart';
import 'package:keydui/state/mappings_controller.dart';
import 'package:keydui/ui/home_page.dart';
import 'package:keydui/ui/mapping_row_tile.dart';

class StubApplyService implements ApplyService {
  StubApplyService(this.result);
  final ApplyResult result;
  @override
  Future<ApplyResult> apply(String configText) async => result;
}

const catalog = KeyCatalog(['esc', 'capslock', 'home', 'left']);
const sample = '[meta]\nleft = home\n';

Future<MappingsController> pumpHome(
  WidgetTester tester, {
  ApplyResult result = const ApplySaved(),
  String config = sample,
}) async {
  final controller = MappingsController(
    applyService: StubApplyService(result),
    readConfig: () async => config,
  );
  await controller.load();
  await tester.pumpWidget(MaterialApp(
    home: HomePage(controller: controller, catalog: catalog),
  ));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('shows a tile per mapping', (tester) async {
    await pumpHome(tester);
    expect(find.byType(MappingRowTile), findsOneWidget);
    expect(find.text('1 mapping'), findsOneWidget);
  });

  testWidgets('empty config shows the empty state', (tester) async {
    await pumpHome(tester, config: '');
    expect(find.byType(MappingRowTile), findsNothing);
    expect(find.textContaining('No mappings yet'), findsOneWidget);
  });

  testWidgets('the FAB adds a row', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(MappingRowTile), findsNWidgets(2));
  });

  testWidgets('save is disabled until dirty, then reports success',
      (tester) async {
    final controller = await pumpHome(tester);
    final saveButton = find.byIcon(Icons.save);
    expect(tester.widget<IconButton>(find.ancestor(
      of: saveButton,
      matching: find.byType(IconButton),
    )).onPressed, isNull);

    controller.updateRow(0, controller.rows[0].copyWith(toKey: 'esc'));
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Mappings applied'), findsOneWidget);
  });

  testWidgets('an invalid config surfaces keyd\'s message', (tester) async {
    final controller =
        await pumpHome(tester, result: const ApplyInvalid('line 2: bad key'));
    controller.updateRow(0, controller.rows[0].copyWith(toKey: 'esc'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(find.textContaining('line 2: bad key'), findsOneWidget);
  });

  testWidgets('a config that could not be read is reported', (tester) async {
    final controller = MappingsController(
      applyService: StubApplyService(const ApplySaved()),
      readConfig: () async => throw const FileSystemException('denied'),
    );
    await controller.load();
    await tester.pumpWidget(MaterialApp(
      home: HomePage(controller: controller, catalog: catalog),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not read'), findsOneWidget);
    expect(find.textContaining(configPath), findsOneWidget);
  });

  testWidgets('a fallback key catalog shows a notice', (tester) async {
    final controller = MappingsController(
      applyService: StubApplyService(const ApplySaved()),
      readConfig: () async => sample,
    );
    await controller.load();
    await tester.pumpWidget(MaterialApp(
      home: HomePage(
        controller: controller,
        catalog: KeyCatalog(fallbackKeys, isFallback: true),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('keyd was not found'), findsOneWidget);
  });

  testWidgets('a cancelled password prompt is reported', (tester) async {
    final controller =
        await pumpHome(tester, result: const ApplyCancelled());
    controller.updateRow(0, controller.rows[0].copyWith(toKey: 'esc'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cancelled'), findsOneWidget);
  });

  testWidgets('a failure to apply is reported', (tester) async {
    final controller =
        await pumpHome(tester, result: const ApplyFailed('disk full'));
    controller.updateRow(0, controller.rows[0].copyWith(toKey: 'esc'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not apply'), findsOneWidget);
    expect(find.textContaining('disk full'), findsOneWidget);
  });

  testWidgets(
      'deleting a row above one with an inline error keeps the error '
      'with its own row, not the list position it vacates',
      (tester) async {
    await pumpHome(
      tester,
      config: '[meta]\nleft = home\nright = end\nup = pageup\n',
    );
    expect(find.byType(MappingRowTile), findsNWidgets(3));

    // Type an unrecognised value into row 1's From field and submit it
    // without it being accepted, leaving an inline error (and the stale
    // typed text) as ephemeral state tied to that row's own element.
    await tester.enterText(
      find.widgetWithText(TextField, 'right'),
      'zzznotakey',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('zzznotakey'), findsOneWidget);
    expect(
      find.text("keyd doesn't recognise this key name."),
      findsOneWidget,
    );

    // Delete row 0 (left -> home); row 1's content shifts up to index 0.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    // The stale text and its error must have followed row 1 to its new
    // position -- not been left behind for row 2's content (now at index 1)
    // to inherit, which is what index-keyed tiles would do.
    expect(find.text('zzznotakey'), findsOneWidget);
    expect(
      find.text("keyd doesn't recognise this key name."),
      findsOneWidget,
    );
    // Row 2's own, untouched value renders cleanly at its new position.
    expect(find.widgetWithText(TextField, 'up'), findsOneWidget);
  });

  testWidgets(
      'didUpdateWidget swaps the controller listener when the parent '
      'supplies a different controller',
      (tester) async {
    final controllerA = MappingsController(
      applyService: StubApplyService(const ApplySaved()),
      readConfig: () async => sample,
    );
    await controllerA.load();
    final controllerB = MappingsController(
      applyService: StubApplyService(const ApplySaved()),
      readConfig: () async => sample,
    );
    await controllerB.load();

    await tester.pumpWidget(MaterialApp(
      home: HomePage(controller: controllerA, catalog: catalog),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(MappingRowTile), findsOneWidget);

    // Same widget position and type, but a different controller: this is a
    // parent rebuild, which should route through didUpdateWidget rather
    // than initState/dispose.
    await tester.pumpWidget(MaterialApp(
      home: HomePage(controller: controllerB, catalog: catalog),
    ));
    await tester.pumpAndSettle();

    // The old controller must no longer drive rebuilds of this page.
    controllerA.addRow();
    await tester.pump();
    expect(find.byType(MappingRowTile), findsOneWidget);

    // The new controller must.
    controllerB.addRow();
    await tester.pump();
    expect(find.byType(MappingRowTile), findsNWidgets(2));
  });
}
