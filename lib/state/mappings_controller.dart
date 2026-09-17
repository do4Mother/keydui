import 'package:flutter/foundation.dart';

import '../models/keyd_config.dart';
import '../models/mapping_row.dart';
import '../models/modifier.dart';
import '../services/apply_service.dart';
import '../services/keyd_config_parser.dart';

class MappingsController extends ChangeNotifier {
  MappingsController({
    required this.applyService,
    required this.readConfig,
  });

  final ApplyService applyService;
  final Future<String> Function() readConfig;

  KeydConfig _config = KeydConfig(const []);
  List<MappingRow> _rows = const [];
  String _baseline = '';
  ApplyResult? _lastResult;
  String? _loadError;
  bool _isLoaded = false;

  // A stable identity per row, independent of list position, so a widget
  // keyed on it (e.g. `ValueKey(keyForRow(i))`) keeps its element -- and
  // any ephemeral field state such as an inline error or a remap warning --
  // attached to the same row across insertions and deletions elsewhere in
  // the list, rather than to whatever index that row happens to occupy.
  List<int> _rowKeys = [];
  int _nextRowKeyId = 0;

  List<MappingRow> get rows => List.unmodifiable(_rows);
  ApplyResult? get lastResult => _lastResult;
  String? get loadError => _loadError;

  /// A stable key for the row at [index], suitable for `ValueKey`. Preserved
  /// across [updateRow] on that same row, freshly minted by [load] and
  /// [addRow], and dropped along with its row by [removeRow].
  Object keyForRow(int index) => _rowKeys[index];

  bool get isDirty => serialize() != _baseline;

  bool get canSave =>
      isDirty &&
      _rows.every((r) => r.fromKey.isNotEmpty && r.toKey.isNotEmpty);

  Future<void> load() async {
    try {
      final text = await readConfig();
      _config = parseKeydConfig(text);
      // Copy modifier sets to avoid sharing between rows in the same section.
      _rows = _config.rows
          .map((row) => MappingRow(
                modifiers: Set.of(row.modifiers),
                fromKey: row.fromKey,
                toKey: row.toKey,
                rawLine: row.rawLine,
              ))
          .toList();
      _rowKeys = List.generate(_rows.length, (_) => _nextRowKeyId++);
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
    _rows = [
      ..._rows,
      const MappingRow(modifiers: {}, fromKey: '', toKey: ''),
    ];
    _rowKeys = [..._rowKeys, _nextRowKeyId++];
    notifyListeners();
  }

  void updateRow(int index, MappingRow row) {
    if (index < 0) {
      throw ArgumentError('index must be non-negative, got $index');
    }
    final next = _rows.toList();
    if (index > next.length) {
      throw RangeError('index $index is out of range for list of length ${next.length}');
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
      nextKeys.add(_nextRowKeyId++);
    }
    _rows = next;
    _rowKeys = nextKeys;
    notifyListeners();
  }

  void removeRow(int index) {
    _rows = (_rows.toList()..removeAt(index));
    _rowKeys = (_rowKeys.toList()..removeAt(index));
    notifyListeners();
  }

  /// If another row already maps something to [capturedKey], returns that
  /// row's pre-remap label (e.g. `meta+left`). keyd rewrites keys below the
  /// display server, so a captured key may be a mapping's output.
  String? remapWarningFor(String capturedKey, {required int excludingIndex}) {
    for (var i = 0; i < _rows.length; i++) {
      if (i == excludingIndex) continue;
      final row = _rows[i];
      if (row.toKey != capturedKey) continue;
      final section = Modifier.sectionName(row.modifiers);
      return section == 'main' ? row.fromKey : '$section+${row.fromKey}';
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
    final text = serialize();
    final result = await applyService.apply(text);
    if (result is ApplySaved) _baseline = text;
    _lastResult = result;
    notifyListeners();
    return result;
  }
}
