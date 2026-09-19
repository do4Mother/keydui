import 'modifier.dart';

/// The right-hand side of a mapping line, as structure rather than a string.
///
/// keyd writes a chord as single-letter prefixes on the key it modifies:
/// `S-home` is Shift+Home and `C-A-f4` is Ctrl+Alt+F4. That notation is what
/// the config file needs and what users have to decode by hand, so the UI
/// parses it into [modifiers] + [key] (which the row renders as chips and a
/// key field) and formats it back on the way out.
///
/// Not every action is a chord. `macro(...)`, `layer(...)`, an AltGr `G-`
/// prefix and anything else this cannot faithfully represent is kept as
/// [raw] and stays editable as text -- see [isAdvanced]. Round-tripping an
/// advanced action never rewrites it.
class KeyAction {
  const KeyAction._({required this.modifiers, required this.key, this.raw});

  /// A chord of zero or more [modifiers] applied to a bare keyd key name.
  factory KeyAction.simple(Set<Modifier> modifiers, String key) =>
      KeyAction._(modifiers: Set.unmodifiable(modifiers), key: key);

  /// An expression the chip UI cannot express; [text] is preserved verbatim.
  factory KeyAction.advanced(String text) =>
      KeyAction._(modifiers: const {}, key: '', raw: text);

  final Set<Modifier> modifiers;

  /// The bare keyd key name, lower-cased. Empty for an advanced action.
  final String key;

  /// The original text of an action that could not be decoded into a chord,
  /// or null for a chord.
  final String? raw;

  bool get isAdvanced => raw != null;

  /// keyd's prefix letter for each modifier. AltGr (`G`) is deliberately
  /// absent: [Modifier] has no AltGr member, so a `G-` action is advanced.
  static const _prefixes = {
    'C': Modifier.control,
    'A': Modifier.alt,
    'M': Modifier.meta,
    'S': Modifier.shift,
  };

  /// A bare keyd key name: `home`, `f4`, `102nd`, `kpdot`. Notably it
  /// contains no `-`, which is what makes prefix stripping unambiguous.
  static final _bareKey = RegExp(r'^[A-Za-z0-9_.]+$');

  static KeyAction parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return KeyAction.simple(const {}, '');

    final modifiers = <Modifier>{};
    var rest = trimmed;
    while (rest.length >= 2 && rest[1] == '-') {
      final modifier = _prefixes[rest[0]];
      // An unknown prefix letter -- `G-` (AltGr) or a typo -- is not
      // something the chips can round-trip, so the whole action is advanced.
      if (modifier == null) return KeyAction.advanced(trimmed);
      modifiers.add(modifier);
      rest = rest.substring(2);
    }

    if (!_bareKey.hasMatch(rest)) return KeyAction.advanced(trimmed);
    return KeyAction.simple(modifiers, rest.toLowerCase());
  }

  /// The keyd text for this action: prefixes in canonical order, then the
  /// key. An advanced action formats back to exactly what was parsed.
  String format() {
    if (raw != null) return raw!;
    if (key.isEmpty) return '';
    final prefix = Modifier.ordered(modifiers)
        .map((m) => '${_letterFor(m)}-')
        .join();
    return '$prefix$key';
  }

  /// The keyd text for [chips] applied to whatever was typed or captured in
  /// a key field.
  ///
  /// A key typed with its own prefix (`S-home`) merges with the chips rather
  /// than replacing them. An advanced entry replaces the chord outright:
  /// keyd has no `C-macro(a b)`, so decorating one with the chips would
  /// write a line it rejects.
  static String compose(Set<Modifier> chips, String typedKey) {
    final typed = parse(typedKey);
    if (typed.isAdvanced) return typed.format();
    if (typed.key.isEmpty) return '';
    return KeyAction.simple({...chips, ...typed.modifiers}, typed.key).format();
  }

  static String _letterFor(Modifier modifier) =>
      _prefixes.entries.firstWhere((entry) => entry.value == modifier).key;
}
