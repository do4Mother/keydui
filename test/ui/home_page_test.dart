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
}
