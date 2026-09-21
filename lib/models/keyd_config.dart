import 'mapping_row.dart';
import 'modifier.dart';

sealed class ConfigElement {}

/// Lines the UI does not model: comments, `[ids]`, named layers, blank lines.
class PassthroughBlock extends ConfigElement {
  PassthroughBlock(this.lines);
  final List<String> lines;
}

sealed class SectionEntry {}

class RowEntry extends SectionEntry {
  RowEntry(this.row);
  final MappingRow row;
}

class RawEntry extends SectionEntry {
  RawEntry(this.line);
  final String line;
}

class MappingSection extends ConfigElement {
  MappingSection({
    required this.modifiers,
    required this.headerLine,
    required this.entries,
  });

  final Set<Modifier> modifiers;
  final String headerLine;
  final List<SectionEntry> entries;
}

class KeydConfig {
  KeydConfig(this.elements, {this.endsWithNewline = true});

  final List<ConfigElement> elements;
  final bool endsWithNewline;

  List<MappingRow> get rows => [
    for (final element in elements)
      if (element is MappingSection)
        for (final entry in element.entries)
          if (entry is RowEntry) entry.row,
  ];

  /// Rebuilds the config so its mapping sections contain exactly [rows].
  KeydConfig withRows(List<MappingRow> rows) {
    final grouped = <String, List<MappingRow>>{};
    for (final row in rows) {
      grouped
          .putIfAbsent(
            Modifier.sectionName(row.modifiers),
            () => <MappingRow>[],
          )
          .add(row);
    }

    // A file may legally repeat a header -- `keyd check` accepts two `[main]`
    // blocks -- so rows cannot simply be handed to "the" section of a given
    // name: the first instance would claim all of them and every later
    // instance would be dropped as empty. Each instance is instead given a
    // share of its name's rows, in document order: its own original row
    // count, with the LAST instance of that name also taking whatever rows
    // were added since. An unedited open-and-save therefore hands every
    // instance back exactly the rows it started with, byte for byte.
    final originalRowCounts = <MappingSection, int>{};
    final instancesLeft = <String, int>{};
    for (final element in elements) {
      if (element is! MappingSection) continue;
      final name = Modifier.sectionName(element.modifiers);
      originalRowCounts[element] = element.entries.whereType<RowEntry>().length;
      instancesLeft[name] = (instancesLeft[name] ?? 0) + 1;
    }

    final result = <ConfigElement>[];
    var lastSectionIndex = -1;
    for (final element in elements) {
      if (element is! MappingSection) {
        result.add(element);
        continue;
      }
      final name = Modifier.sectionName(element.modifiers);
      final pending = grouped[name] ?? const <MappingRow>[];
      final isLastInstance =
          (instancesLeft[name] = instancesLeft[name]! - 1) == 0;
      final share = isLastInstance
          ? pending.length
          : (originalRowCounts[element]! < pending.length
                ? originalRowCounts[element]!
                : pending.length);
      final sectionRows = pending.sublist(0, share);
      grouped[name] = pending.sublist(share);
      if (sectionRows.isEmpty) {
        // Section emptied out; drop it, and with it the standalone blank
        // line that separated it from what came before, so an
        // add-then-remove cycle does not leave a blank line behind on every
        // pass. Only an all-blank passthrough block is touched: a blank line
        // that trails real content belongs to that content, not to the
        // section being dropped.
        // ... and, unless the section carried its own trailing blank line
        // (which goes away with it), the blank line that separated it from
        // what came before, so an add-then-remove cycle does not leave one
        // behind on every pass.
        final endsBlank =
            element.entries.isNotEmpty &&
            element.entries.last is RawEntry &&
            (element.entries.last as RawEntry).line.trim().isEmpty;
        if (!endsBlank) _dropSeparatorBlankLine(result);
        continue;
      }

      // Reconstruct entries preserving RawEntry positions and filling RowEntry slots.
      final newEntries = <SectionEntry>[];
      var rowIndex = 0;
      for (final entry in element.entries) {
        if (entry is RawEntry) {
          newEntries.add(entry); // Preserve RawEntry in its original position
        } else if (entry is RowEntry && rowIndex < sectionRows.length) {
          newEntries.add(RowEntry(sectionRows[rowIndex++]));
        }
        // If rowIndex >= sectionRows.length, skip this RowEntry slot
      }
      // Append any remaining new rows after the last entry.
      while (rowIndex < sectionRows.length) {
        newEntries.add(RowEntry(sectionRows[rowIndex++]));
      }

      result.add(
        MappingSection(
          modifiers: element.modifiers,
          headerLine: element.headerLine,
          entries: newEntries,
        ),
      );
      lastSectionIndex = result.length - 1;
    }

    // Groups with no existing section, in first-appearance order. Names that
    // an existing section already absorbed are left with an empty list here.
    for (final entry in grouped.entries) {
      if (entry.value.isEmpty) continue;
      final modifiers = Modifier.parseSectionName(entry.key)!;
      final section = MappingSection(
        modifiers: modifiers,
        headerLine: '[${entry.key}]',
        entries: entry.value.map(RowEntry.new).toList(),
      );
      // If no existing mapping section, append at end; otherwise after the last section.
      final insertAt = lastSectionIndex >= 0
          ? lastSectionIndex + 1
          : result.length;
      result.insertAll(insertAt, [
        PassthroughBlock(const ['']),
        section,
      ]);
      lastSectionIndex = insertAt + 1;
    }

    _ensureIdsSection(result);

    return KeydConfig(result, endsWithNewline: endsWithNewline);
  }

  /// keyd binds a config to devices through its `[ids]` section: a file
  /// without one matches no keyboard at all. Nothing catches that for the
  /// user -- `keyd check` accepts such a file and `keyd reload` succeeds --
  /// so a config saved without `[ids]` is reported as applied and then
  /// silently remaps nothing. It happens whenever keydui writes the first
  /// config a machine has ever had, since there is then no existing `[ids]`
  /// block to pass through.
  ///
  /// So if [result] holds mappings but no `[ids]`, open the file with the
  /// catch-all form, `*`, which matches every keyboard not explicitly
  /// excluded. An `[ids]` the user already has -- whether `*` or a list of
  /// device ids -- is passthrough like any other unmodelled section and is
  /// left exactly as it is.
  static void _ensureIdsSection(List<ConfigElement> result) {
    if (!result.any((element) => element is MappingSection)) return;
    if (result.any(
      (element) =>
          element is PassthroughBlock &&
          element.lines.any((line) => line.trim() == '[ids]'),
    )) {
      return;
    }

    // The section needs a blank line between it and what follows, unless
    // what follows already opens with one.
    final first = result.first;
    final followedByBlank =
        first is PassthroughBlock &&
        first.lines.isNotEmpty &&
        first.lines.first.trim().isEmpty;
    result.insert(
      0,
      PassthroughBlock(
        followedByBlank ? const ['[ids]', '*'] : const ['[ids]', '*', ''],
      ),
    );
  }

  /// Removes one trailing blank line from whatever [result] currently ends
  /// with: the blank RawEntry closing a mapping section, or a passthrough
  /// block made purely of blank lines -- the shape [withRows] itself emits as
  /// a separator before a freshly added section. A blank line trailing real
  /// passthrough content belongs to that content and is left alone.
  ///
  /// Nothing is mutated in place: `elements` is shared -- [withRows] runs
  /// against the same parsed config on every serialize -- and the separator
  /// block this class emits holds a const list.
  static void _dropSeparatorBlankLine(List<ConfigElement> result) {
    if (result.isEmpty) return;
    final last = result.last;
    if (last is PassthroughBlock) {
      if (last.lines.isEmpty || last.lines.any((line) => line.isNotEmpty)) {
        return;
      }
      result.removeLast();
      final kept = last.lines.sublist(0, last.lines.length - 1);
      if (kept.isNotEmpty) result.add(PassthroughBlock(kept));
      return;
    }
    if (last is MappingSection) {
      final entries = last.entries;
      if (entries.isEmpty) return;
      final tail = entries.last;
      if (tail is! RawEntry || tail.line.trim().isNotEmpty) return;
      result.removeLast();
      result.add(
        MappingSection(
          modifiers: last.modifiers,
          headerLine: last.headerLine,
          entries: entries.sublist(0, entries.length - 1),
        ),
      );
    }
  }
}
