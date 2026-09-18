import 'modifier.dart';

/// A mapping that already rewrites some key to the one just captured.
///
/// keyd rewrites keys below the display server, so a captured key may be
/// another mapping's *output*: pressing the key that physically produces
/// `home` on a `[meta] left = home` machine captures `home`, not `left`.
/// This carries the offending mapping's pre-remap trigger as STRUCTURE --
/// its section's modifiers plus its bare key name -- rather than as the
/// flattened `meta+left` display string. A row built from the flattened
/// string would serialize to `meta+left = …` inside `[main]`, which keyd
/// rejects ("meta is not a valid key"); the two halves have to be applied
/// to the row's modifier chips and key field respectively.
class RemapWarning {
  const RemapWarning({required this.modifiers, required this.fromKey});

  final Set<Modifier> modifiers;
  final String fromKey;

  /// How the mapping reads to a user, e.g. `meta+left` or plain `capslock`.
  String get label => modifiers.isEmpty
      ? fromKey
      : '${Modifier.sectionName(modifiers)}+$fromKey';
}
