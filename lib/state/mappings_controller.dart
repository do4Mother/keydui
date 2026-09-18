import 'package:flutter/foundation.dart';

import '../models/keyd_config.dart';
import '../models/mapping_row.dart';
import '../models/remap_warning.dart';
import '../services/apply_service.dart';
import '../services/keyd_config_parser.dart';

class MappingsController extends ChangeNotifier {
  MappingsController({required this.applyService, required this.readConfig});

  final ApplyService applyService;
  final Future<String> Function() readConfig;

  KeydConfig _config = KeydConfig(const []);
  List<MappingRow> _rows = const [];
  String _baseline = '';
  ApplyResult? _lastResult;
  String? _loadError;
  bool _isLoaded = false;
  bool _saving = false;

  // A stable identity per row, independent of list position, so a widget
  // keyed on it (e.g. `ValueKey(keyForRow(i))`) keeps its element -- and
  // any ephemeral field state such as an inline error or a remap warning --
  // attached to the same row across insertions and deletions elsewhere in
  // the list, rather than to whatever index that row happens to occupy.
  //
  // Each key is a fresh `Object()`, compared by identity, rather than a
  // per-instance counter: a counter restarting at 0 in every controller
  // would let two different `MappingsController`s (e.g. across a
  // `didUpdateWidget` swap to a different controller at the same widget
  // position) mint identical key sequences, which would let a `ValueKey`
  // built from those keys wrongly match rows across controllers and reuse
  // one row's ephemeral field state for an unrelated row in the other
  // controller. `Object()` identity makes that collision impossible by
  // construction instead of merely unlikely.
  List<Object> _rowKeys = [];

  List<MappingRow> get rows => List.unmodifiable(_rows);
  ApplyResult? get lastResult => _lastResult;
  String? get loadError => _loadError;

  /// Whether a [save] is in flight: `keyd check`, then the polkit prompt,
  /// then the privileged helper. Nothing about that sequence is instant, so
  /// the UI has to show it is happening and keep the user out of it.
  bool get isSaving => _saving;

  /// A stable key for the row at [index], suitable for `ValueKey`. Preserved
  /// across [updateRow] on that same row, freshly minted by [load] and
  /// [addRow], and dropped along with its row by [removeRow].
  Object keyForRow(int index) => _rowKeys[index];

  bool get isDirty => serialize() != _baseline;

  /// False while a save is in flight: two concurrent privileged helpers
  /// share one staging path and one backup file, so run B's backup step can
  /// copy run A's already-installed NEW config over the pre-edit backup --
  /// destroying the only copy of what the user had before.
  bool get canSave =>
      !_saving &&
      isDirty &&
      _rows.every((r) => r.fromKey.isNotEmpty && r.toKey.isNotEmpty);

  Future<void> load() async {
    try {
      final text = await readConfig();
      _config = parseKeydConfig(text);
      // Copy modifier sets to avoid sharing between rows in the same section.
      _rows = _config.rows
          .map(
            (row) => MappingRow(
              modifiers: Set.of(row.modifiers),
              fromKey: row.fromKey,
              toKey: row.toKey,
              rawLine: row.rawLine,
            ),
          )
          .toList();
      _rowKeys = List.generate(_rows.length, (_) => Object());
      _baseline = serialize();
      _loadError = null;
      _isLoaded = true;
    } catch (e) {
      _loadError = '$e';
      _isLoaded = false;
    }
    notifyListeners();
  }

  String serialize() => serializeKeydConfig(_config.withRows(_rows));

  void addRow() {
    _rows = [..._rows, const MappingRow(modifiers: {}, fromKey: '', toKey: '')];
    _rowKeys = [..._rowKeys, Object()];
    notifyListeners();
  }

  void updateRow(int index, MappingRow row) {
    if (index < 0) {
      throw ArgumentError('index must be non-negative, got $index');
    }
    final next = _rows.toList();
    if (index > next.length) {
      throw RangeError(
        'index $index is out of range for list of length ${next.length}',
      );
    }
    // Copy modifier set to avoid sharing between rows.
    final rowWithFreshModifiers = MappingRow(
      modifiers: Set.of(row.modifiers),
      fromKey: row.fromKey,
      toKey: row.toKey,
      rawLine: row.rawLine,
    );
    final nextKeys = _rowKeys.toList();
    if (index < next.length) {
      next[index] = rowWithFreshModifiers;
    } else {
      next.add(rowWithFreshModifiers);
      nextKeys.add(Object());
    }
    _rows = next;
    _rowKeys = nextKeys;
    notifyListeners();
  }

  void removeRow(int index) {
    if (index < 0) {
      throw ArgumentError('index must be non-negative, got $index');
    }
    if (index >= _rows.length) {
      throw RangeError(
        'index $index is out of range for list of length ${_rows.length}',
      );
    }
    _rows = (_rows.toList()..removeAt(index));
    _rowKeys = (_rowKeys.toList()..removeAt(index));
    notifyListeners();
  }

  /// If another row already maps something to [capturedKey], returns that
  /// row's pre-remap trigger. keyd rewrites keys below the display server,
  /// so a captured key may be a mapping's output.
  ///
  /// The trigger is returned as modifiers plus a bare key name rather than a
  /// flattened `meta+left` label, so a caller can apply both halves to the
  /// right places on the row instead of stuffing `meta+left` into the key
  /// field, which would serialize to a line keyd rejects.
  RemapWarning? remapWarningFor(
    String capturedKey, {
    required int excludingIndex,
  }) {
    for (var i = 0; i < _rows.length; i++) {
      if (i == excludingIndex) continue;
      final row = _rows[i];
      if (row.toKey != capturedKey) continue;
      return RemapWarning(
        modifiers: Set.of(row.modifiers),
        fromKey: row.fromKey,
      );
    }
    return null;
  }

  Future<ApplyResult> save() async {
    if (!_isLoaded) {
      final result = const ApplyFailed('Config was not loaded');
      _lastResult = result;
      notifyListeners();
      return result;
    }
    if (_saving) {
      // Belt and braces: `canSave` already gates the button, but a second
      // helper run must never start on top of the first.
      return const ApplyFailed('A save is already in progress');
    }
    _saving = true;
    notifyListeners();
    try {
      final text = serialize();
      final result = await applyService.apply(text);
      if (result is ApplySaved) _baseline = text;
      _lastResult = result;
      return result;
    } finally {
      // Cleared in a finally so a throwing apply service cannot wedge the
      // Save button off for the rest of the session.
      _saving = false;
      notifyListeners();
    }
  }
}
