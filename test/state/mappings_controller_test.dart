import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'dart:io';

import 'package:keydui/models/mapping_row.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/services/apply_service.dart';
import 'package:keydui/state/mappings_controller.dart';

class BlockingApplyService implements ApplyService {
  BlockingApplyService(this.result);
  final ApplyResult result;
  final List<String> applied = [];
  final gate = Completer<void>();

  @override
  Future<ApplyResult> apply(String configText) async {
    applied.add(configText);
    await gate.future;
    return result;
  }
}

class ThrowingApplyService implements ApplyService {
  @override
  Future<ApplyResult> apply(String configText) async =>
      throw const FileSystemException('No space left on device');
}

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
    final warning = c.remapWarningFor('home', excludingIndex: 1);
    // Structure, not a flattened label: `meta+left` is not a key name.
    expect(warning, isNotNull);
    expect(warning!.modifiers, {Modifier.meta});
    expect(warning.fromKey, 'left');
    expect(warning.label, 'meta+left');
    expect(c.remapWarningFor('home', excludingIndex: 0), isNull);
    expect(c.remapWarningFor('f4', excludingIndex: 1), isNull);
  });

  test('a warning for an unmodified mapping has no modifiers', () async {
    final c = MappingsController(
      applyService: RecordingApplyService(const ApplySaved()),
      readConfig: () async => '[main]\ncapslock = esc\nf1 = f2\n',
    );
    await c.load();
    final warning = c.remapWarningFor('esc', excludingIndex: 1);
    expect(warning!.modifiers, isEmpty);
    expect(warning.fromKey, 'capslock');
    expect(warning.label, 'capslock');
  });

  test(
    'applying a remap warning serializes to a config keyd accepts',
    () async {
      final c = controllerWith(const ApplySaved());
      await c.load();
      c.addRow();
      final warning = c.remapWarningFor('home', excludingIndex: 2)!;
      c.updateRow(
        2,
        c.rows[2].copyWith(
          modifiers: warning.modifiers,
          fromKey: warning.fromKey,
          toKey: 'pageup',
        ),
      );
      // The modifier half has to land in the section header, never in the key
      // name: `meta+left = pageup` inside `[main]` is what keyd rejects.
      expect(c.serialize(), contains('[meta]'));
      expect(c.serialize(), isNot(contains('meta+left =')));
      expect(c.serialize(), contains('left = pageup'));
    },
  );

  test(
    'save() after failed load returns ApplyFailed without calling apply',
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
    },
  );

  test('updateRow with index > length throws RangeError', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    expect(
      () => c.updateRow(
        10,
        const MappingRow(modifiers: {}, fromKey: 'a', toKey: 'b'),
      ),
      throwsRangeError,
    );
  });

  test('updateRow with negative index throws ArgumentError', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    expect(
      () => c.updateRow(
        -1,
        const MappingRow(modifiers: {}, fromKey: 'a', toKey: 'b'),
      ),
      throwsArgumentError,
    );
  });

  test('each loaded row has its own modifier set instance', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    // Two rows in [meta] section; their modifier sets should be independent objects.
    expect(identical(c.rows[0].modifiers, c.rows[1].modifiers), isFalse);
  });

  test('row keys are stable across updateRow, change on addRow, and drop with removeRow', () async {
    // These assertions care only that each key is a stable, distinct
    // identity -- never what it actually is (e.g. not that it's an int, or
    // that keys are sequential). `same()` checks object identity, which is
    // what `ValueKey` equality (and thus tile-state preservation) relies on.
    final c = controllerWith(const ApplySaved());
    await c.load();
    final key0 = c.keyForRow(0);
    final key1 = c.keyForRow(1);
    expect(key0, isNot(same(key1)));

    // A committed edit keeps the same identity for both rows.
    c.updateRow(0, c.rows[0].copyWith(toKey: 'pageup'));
    expect(c.keyForRow(0), same(key0));
    expect(c.keyForRow(1), same(key1));

    // A newly appended row (via addRow) gets a fresh key.
    c.addRow();
    final key2 = c.keyForRow(2);
    expect(key2, isNot(same(key0)));
    expect(key2, isNot(same(key1)));

    // Removing row 0 drops its key and shifts the others up with it.
    c.removeRow(0);
    expect(c.keyForRow(0), same(key1));
    expect(c.keyForRow(1), same(key2));
  });

  test(
    'two controllers loaded with the same row count mint distinct keys',
    () async {
      // A counter-based key (restarting at 0 per instance) would let two
      // controllers of the same shape mint identical key sequences. That
      // collision would let a `ValueKey` wrongly match rows across a
      // `didUpdateWidget` controller swap and reuse one row's ephemeral field
      // state for an unrelated row in the other controller.
      final a = controllerWith(const ApplySaved());
      await a.load();
      final b = controllerWith(const ApplySaved());
      await b.load();
      expect(a.keyForRow(0), isNot(same(b.keyForRow(0))));
      expect(a.keyForRow(1), isNot(same(b.keyForRow(1))));
    },
  );

  test('removeRow with index >= length throws RangeError', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    expect(() => c.removeRow(10), throwsRangeError);
    expect(() => c.removeRow(c.rows.length), throwsRangeError);
  });

  test('removeRow with negative index throws ArgumentError', () async {
    final c = controllerWith(const ApplySaved());
    await c.load();
    expect(() => c.removeRow(-1), throwsArgumentError);
  });

  test(
    'mutating one row\'s modifiers does not affect other rows in same section',
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
    },
  );

  test('a second save is refused while the first is in flight', () async {
    final service = BlockingApplyService(const ApplySaved());
    final c = MappingsController(
      applyService: service,
      readConfig: () async => sample,
    );
    await c.load();
    c.updateRow(0, c.rows[0].copyWith(toKey: 'pageup'));
    expect(c.canSave, isTrue);

    final first = c.save();
    // Two concurrent privileged helpers share one staging path and one
    // backup file; the second run's backup would overwrite the pre-edit
    // config with the first run's freshly installed one.
    expect(c.isSaving, isTrue);
    expect(c.canSave, isFalse);
    final second = await c.save();
    expect(second, isA<ApplyFailed>());
    expect(service.applied, hasLength(1));

    service.gate.complete();
    expect(await first, isA<ApplySaved>());
    expect(c.isSaving, isFalse);
    expect(c.canSave, isFalse); // clean again after a successful save
  });

  test('a throwing apply service does not wedge the save button off', () async {
    final c = MappingsController(
      applyService: ThrowingApplyService(),
      readConfig: () async => sample,
    );
    await c.load();
    c.updateRow(0, c.rows[0].copyWith(toKey: 'pageup'));
    await expectLater(c.save(), throwsA(isA<FileSystemException>()));
    expect(c.isSaving, isFalse);
    expect(c.canSave, isTrue);
  });

  test('isSaving notifies listeners on both edges', () async {
    final service = BlockingApplyService(const ApplySaved());
    final c = MappingsController(
      applyService: service,
      readConfig: () async => sample,
    );
    await c.load();
    c.updateRow(0, c.rows[0].copyWith(toKey: 'pageup'));
    final seen = <bool>[];
    c.addListener(() => seen.add(c.isSaving));
    final future = c.save();
    service.gate.complete();
    await future;
    expect(seen, containsAllInOrder([true, false]));
  });
}
