enum Modifier {
  control('control'),
  alt('alt'),
  meta('meta'),
  shift('shift');

  const Modifier(this.keydName);

  final String keydName;

  /// Canonical order: control, alt, meta, shift.
  static List<Modifier> ordered(Iterable<Modifier> mods) =>
      Modifier.values.where(mods.toSet().contains).toList();

  static String sectionName(Set<Modifier> mods) =>
      mods.isEmpty ? 'main' : ordered(mods).map((m) => m.keydName).join('+');

  /// Returns the modifier set for a section name, or null if [name] is not a
  /// modifier section (e.g. `ids`, or a user-defined layer).
  static Set<Modifier>? parseSectionName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed == 'main') return <Modifier>{};
    final result = <Modifier>{};
    for (final part in trimmed.split('+')) {
      final name = part.trim();
      Modifier? match;
      for (final modifier in Modifier.values) {
        if (modifier.keydName == name) match = modifier;
      }
      if (match == null) return null;
      result.add(match);
    }
    return result;
  }
}
