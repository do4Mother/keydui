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

  List<MappingRow> get rows => List.unmodifiable(_rows);
  ApplyResult? get lastResult => _lastResult;
  String? get loadError => _loadError;

  bool get isDirty => serialize() != _baseline;

  bool get canSave =>
      isDirty &&
      _rows.every((r) => r.fromKey.isNotEmpty && r.toKey.isNotEmpty);

  Future<void> load() async {
    try {
      final text = await readConfig();
      _config = parseKeydConfig(text);
      _rows = _config.rows.toList();
      _baseline = serialize();
      _loadError = null;
    } catch (e) {
      _loadError = '$e';
    }
    notifyListeners();
  }

  String serialize() => serializeKeydConfig(_config.withRows(_rows));

  void addRow() {
    _rows = [
      ..._rows,
      const MappingRow(modifiers: {}, fromKey: '', toKey: ''),
    ];
    notifyListeners();
  }

  void updateRow(int index, MappingRow row) {
    final next = _rows.toList();
    if (index < next.length) {
      next[index] = row;
    } else {
      next.add(row);
    }
    _rows = next;
    notifyListeners();
  }

  void removeRow(int index) {
    _rows = (_rows.toList()..removeAt(index));
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
    final text = serialize();
    final result = await applyService.apply(text);
    if (result is ApplySaved) _baseline = text;
    _lastResult = result;
    notifyListeners();
    return result;
  }
}
