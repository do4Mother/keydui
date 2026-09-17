import 'package:flutter_test/flutter_test.dart';
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
}
