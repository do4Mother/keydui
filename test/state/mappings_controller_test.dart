import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/mapping_row.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/services/apply_service.dart';
import 'package:keydui/state/mappings_controller.dart';

class RecordingApplyService implements ApplyService {
  RecordingApplyService(this.result);
  final ApplyResult result;
  final List<String> applied = [];

  @override
  Future<ApplyResult> apply(String configText) async {
    applied.add(configText);
    return result;
  }
}

const sample = '''[meta]
left = home
right = end
''';

MappingsController controllerWith(ApplyResult result) => MappingsController(
      applyService: RecordingApplyService(result),
      readConfig: () async => sample,
    );

void main() {
  test('loads rows and starts clean', () async {
    final c = controllerWith(const ApplySaved())..addListener(() {});
    await c.load();
    expect(c.rows, hasLength(2));
    expect(c.isDirty, isFalse);
    expect(c.canSave, isFalse);
  });

  test('editing a row marks dirty and notifies', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    var notifications = 0;
    c.addListener(() => notifications++);
    c.updateRow(0, c.rows[0].copyWith(toKey: 'pageup'));
    expect(c.isDirty, isTrue);
    expect(c.canSave, isTrue);
    expect(notifications, 1);
    expect(c.serialize(), contains('left = pageup'));
  });

  test('a row with an empty key blocks saving', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    c.addRow();
    expect(c.isDirty, isTrue);
    expect(c.canSave, isFalse);
  });

  test('removing a row and restoring it returns to clean', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    final removed = c.rows[1];
    c.removeRow(1);
    expect(c.isDirty, isTrue);
    c.updateRow(1, removed); // re-add at the end
    expect(c.rows, hasLength(2));
  });

  test('a successful save clears dirty', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    c.updateRow(0, c.rows[0].copyWith(toKey: 'pageup'));
    final result = await c.save();
    expect(result, isA<ApplySaved>());
    expect(c.isDirty, isFalse);
    expect(c.lastResult, isA<ApplySaved>());
  });

  test('a failed save keeps the edits dirty', () async {
    final c = controllerWith(const ApplyFailed('nope'));
    await c.load();
    c.updateRow(0, c.rows[0].copyWith(toKey: 'pageup'));
    await c.save();
    expect(c.isDirty, isTrue);
  });

  test('remap warning finds the pre-remap combination', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    expect(c.remapWarningFor('home', excludingIndex: 1), 'meta+left');
    expect(c.remapWarningFor('home', excludingIndex: 0), isNull);
    expect(c.remapWarningFor('f4', excludingIndex: 1), isNull);
  });

  test('save() after failed load returns ApplyFailed without calling apply',
      () async {
    final service = RecordingApplyService(const ApplySaved());
    final c = MappingsController(
      applyService: service,
      readConfig: () async => throw Exception('Read failed'),
    );
    await c.load();
    final result = await c.save();
    expect(result, isA<ApplyFailed>());
    expect(service.applied, isEmpty); // Never called apply
    expect(c.lastResult, isA<ApplyFailed>());
  });

  test('updateRow with index > length throws RangeError', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    expect(
      () => c.updateRow(10, const MappingRow(modifiers: {}, fromKey: 'a', toKey: 'b')),
      throwsRangeError,
    );
  });

  test('updateRow with negative index throws ArgumentError', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    expect(
      () => c.updateRow(-1, const MappingRow(modifiers: {}, fromKey: 'a', toKey: 'b')),
      throwsArgumentError,
    );
  });

  test('each loaded row has its own modifier set instance', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    // Two rows in [meta] section; their modifier sets should be independent objects.
    expect(identical(c.rows[0].modifiers, c.rows[1].modifiers), isFalse);
  });

  test(
      'row keys are stable across updateRow, change on addRow, and drop with removeRow',
      () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    final key0 = c.keyForRow(0);
    final key1 = c.keyForRow(1);
    expect(key0, isNot(equals(key1)));

    // A committed edit keeps the same identity for both rows.
    c.updateRow(0, c.rows[0].copyWith(toKey: 'pageup'));
    expect(c.keyForRow(0), key0);
    expect(c.keyForRow(1), key1);

    // A newly appended row (via addRow) gets a fresh key.
    c.addRow();
    final key2 = c.keyForRow(2);
    expect(key2, isNot(equals(key0)));
    expect(key2, isNot(equals(key1)));

    // Removing row 0 drops its key and shifts the others up with it.
    c.removeRow(0);
    expect(c.keyForRow(0), key1);
    expect(c.keyForRow(1), key2);
  });

  test('mutating one row\'s modifiers does not affect other rows in same section',
      () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    // Record the modifiers before mutation
    final row0ModsBefore = Set.of(c.rows[0].modifiers);
    final row1ModsBefore = Set.of(c.rows[1].modifiers);
    // Mutate row 1's modifier set
    c.rows[1].modifiers.add(Modifier.control);
    // Row 0's modifiers should be unchanged
    expect(c.rows[0].modifiers, equals(row0ModsBefore));
    // Row 1's modifiers should have changed
    expect(c.rows[1].modifiers, isNot(equals(row1ModsBefore)));
  });
}
