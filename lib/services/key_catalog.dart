import 'process_runner.dart';

/// Used when `keyd list-keys` is unavailable. Covers the common 104-key set;
/// the real catalog from keyd v2.6.0 has 319 entries. This is `final`, not
/// `const`: a const collection literal cannot contain `for` elements.
final fallbackKeys = <String>[
  'esc',
  'escape',
  'tab',
  'capslock',
  'space',
  'enter',
  'backspace',
  'leftshift',
  'rightshift',
  'leftcontrol',
  'rightcontrol',
  'leftalt',
  'rightalt',
  'leftmeta',
  'rightmeta',
  'compose',
  'grave',
  'minus',
  'equal',
  'leftbrace',
  'rightbrace',
  'backslash',
  'semicolon',
  'apostrophe',
  'comma',
  'dot',
  'slash',
  '102nd',
  'up',
  'down',
  'left',
  'right',
  'home',
  'end',
  'pageup',
  'pagedown',
  'insert',
  'delete',
  'sysrq',
  'scrolllock',
  'numlock',
  'kpenter',
  for (var i = 1; i <= 12; i++) 'f$i',
  for (var c = 'a'.codeUnitAt(0); c <= 'z'.codeUnitAt(0); c++)
    String.fromCharCode(c),
  for (var d = 0; d <= 9; d++) '$d',
];

class KeyCatalog {
  const KeyCatalog(this.keys, {this.isFallback = false});

  final List<String> keys;
  final bool isFallback;

  static KeyCatalog parse(String stdout, {bool isFallback = false}) {
    final seen = <String>{};
    final keys = <String>[];
    for (final line in stdout.split('\n')) {
      final key = line.trim();
      if (key.isNotEmpty && seen.add(key)) keys.add(key);
    }
    return KeyCatalog(keys, isFallback: isFallback);
  }

  static Future<KeyCatalog> load(ProcessRunner runner) async {
    final outcome = await runner.run('keyd', ['list-keys']);
    if (!outcome.succeeded || outcome.stdout.trim().isEmpty) {
      return KeyCatalog(fallbackKeys, isFallback: true);
    }
    return parse(outcome.stdout);
  }

  bool contains(String key) => keys.contains(key);

  List<String> search(String query, {int limit = 30}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return keys.take(limit).toList();
    final prefix = <String>[];
    final substring = <String>[];
    for (final key in keys) {
      final lower = key.toLowerCase();
      if (lower.startsWith(q)) {
        prefix.add(key);
      } else if (lower.contains(q)) {
        substring.add(key);
      }
    }
    return [...prefix, ...substring].take(limit).toList();
  }
}
