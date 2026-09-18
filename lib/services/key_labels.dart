import '../models/modifier.dart';

/// Display names for keys and modifiers.
///
/// keyd's own vocabulary is what goes in the config file -- `leftmeta`,
/// `pageup`, `sysrq` -- and it is not what is printed on anyone's keyboard.
/// These translate in both directions so the UI can show `Left Super` while
/// still writing `leftmeta`. Nothing here ever reaches disk: the row model
/// keeps keyd names throughout, and [keydNameForLabel] converts back the
/// moment a user submits typed text.
const _labels = <String, String>{
  'esc': 'Esc',
  'escape': 'Escape',
  'tab': 'Tab',
  'capslock': 'Caps Lock',
  'space': 'Space',
  'enter': 'Enter',
  'backspace': 'Backspace',
  'compose': 'Menu',
  'sysrq': 'Print Screen',
  'scrolllock': 'Scroll Lock',
  'numlock': 'Num Lock',
  'kpenter': 'Numpad Enter',
  'insert': 'Insert',
  'delete': 'Delete',
  'home': 'Home',
  'end': 'End',
  'pageup': 'Page Up',
  'pagedown': 'Page Down',
  'up': 'Up Arrow',
  'down': 'Down Arrow',
  'left': 'Left Arrow',
  'right': 'Right Arrow',
  'leftshift': 'Left Shift',
  'rightshift': 'Right Shift',
  'leftcontrol': 'Left Ctrl',
  'rightcontrol': 'Right Ctrl',
  'leftalt': 'Left Alt',
  'rightalt': 'Right Alt',
  'leftmeta': 'Left Super',
  'rightmeta': 'Right Super',
  // Punctuation reads best as the character it types.
  'grave': '`',
  'minus': '-',
  'equal': '=',
  'leftbrace': '[',
  'rightbrace': ']',
  'backslash': r'\',
  'semicolon': ';',
  'apostrophe': "'",
  'comma': ',',
  'dot': '.',
  'slash': '/',
};

/// The keyd names [keyLabel] renames. Everything else is capitalized or
/// upper-cased by rule.
Iterable<String> get labelledKeys => _labels.keys;

final Map<String, String> _reverse = {
  for (final entry in _labels.entries) _normalize(entry.value): entry.key,
};

String _normalize(String text) => text.trim().toLowerCase().replaceAll(' ', '');

/// How [keydName] reads to a user: `pageup` becomes `Page Up`, `f4` becomes
/// `F4`, a lone letter is upper-cased, and an unlisted name is capitalized
/// rather than hidden.
String keyLabel(String keydName) {
  final name = keydName.trim();
  if (name.isEmpty) return '';
  final label = _labels[name.toLowerCase()];
  if (label != null) return label;
  if (RegExp(r'^f[0-9]{1,2}$').hasMatch(name)) return name.toUpperCase();
  if (name.length == 1) return name.toUpperCase();
  return name[0].toUpperCase() + name.substring(1);
}

/// The keyd name behind a display label, for text the user typed.
///
/// Accepts either vocabulary -- `Left Arrow` and `left` both resolve to
/// `left` -- and falls back to the lower-cased input so an unlisted key name
/// still reaches keyd unchanged (the key field, not this, decides whether an
/// unknown name is acceptable).
String keydNameForLabel(String label) =>
    knownKeydNameForLabel(label) ?? label.trim().toLowerCase();

/// The keyd name behind a display label, or null if [label] is not one.
///
/// A field holding a keyd *action* rather than a key name needs this rather
/// than [keydNameForLabel]: `S-home` and `macro(a b)` must survive a
/// submission byte for byte, and lower-casing them silently breaks them.
String? knownKeydNameForLabel(String label) => _reverse[_normalize(label)];

/// What to search the key catalog for, given part of a display label.
///
/// Spaces are dropped so `page up` finds `pageup` while `pageup` typed
/// directly still works.
String keySearchQuery(String input) =>
    knownKeydNameForLabel(input) ?? _normalize(input);

/// How [modifier] reads to a user: `Ctrl`, `Alt`, `Super`, `Shift`.
String modifierLabel(Modifier modifier) => switch (modifier) {
  Modifier.control => 'Ctrl',
  Modifier.alt => 'Alt',
  Modifier.meta => 'Super',
  Modifier.shift => 'Shift',
};

/// A whole chord in display form, e.g. `Ctrl + Alt + F4`. Modifiers with no
/// key yet read as `Ctrl + …` so a half-built chord still makes sense.
String chordLabel(Set<Modifier> modifiers, String key) {
  final parts = [
    ...Modifier.ordered(modifiers).map(modifierLabel),
    if (key.trim().isNotEmpty) keyLabel(key) else if (modifiers.isNotEmpty) '…',
  ];
  return parts.join(' + ');
}
