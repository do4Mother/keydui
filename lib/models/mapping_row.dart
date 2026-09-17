import 'modifier.dart';

class MappingRow {
  const MappingRow({
    required this.modifiers,
    required this.fromKey,
    required this.toKey,
    this.rawLine,
  });

  final Set<Modifier> modifiers;
  final String fromKey;
  final String toKey;

  /// The line exactly as read from disk, or null for rows created or edited in
  /// the UI. Present rows serialize verbatim, which keeps untouched files
  /// byte-identical.
  final String? rawLine;

  /// Editing always drops [rawLine]; the row re-renders canonically.
  MappingRow copyWith({
    Set<Modifier>? modifiers,
    String? fromKey,
    String? toKey,
  }) =>
      MappingRow(
        modifiers: modifiers ?? this.modifiers,
        fromKey: fromKey ?? this.fromKey,
        toKey: toKey ?? this.toKey,
      );

  String render() => rawLine ?? '$fromKey = $toKey';
}
