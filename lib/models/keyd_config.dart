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
          .putIfAbsent(Modifier.sectionName(row.modifiers), () => <MappingRow>[])
          .add(row);
    }

    final result = <ConfigElement>[];
    var lastSectionIndex = -1;
    for (final element in elements) {
      if (element is! MappingSection) {
        result.add(element);
        continue;
      }
      final name = Modifier.sectionName(element.modifiers);
      final sectionRows = grouped.remove(name) ?? const <MappingRow>[];
      if (sectionRows.isEmpty) continue; // section emptied out; drop it

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

      result.add(MappingSection(
        modifiers: element.modifiers,
        headerLine: element.headerLine,
        entries: newEntries,
      ));
      lastSectionIndex = result.length - 1;
    }

    // Groups with no existing section, in first-appearance order.
    for (final entry in grouped.entries) {
      final modifiers = Modifier.parseSectionName(entry.key)!;
      final section = MappingSection(
        modifiers: modifiers,
        headerLine: '[${entry.key}]',
        entries: entry.value.map(RowEntry.new).toList(),
      );
      // If no existing mapping section, append at end; otherwise after the last section.
      final insertAt = lastSectionIndex >= 0 ? lastSectionIndex + 1 : result.length;
      result.insertAll(insertAt, [PassthroughBlock(const ['']), section]);
      lastSectionIndex = insertAt + 1;
    }

    return KeydConfig(result, endsWithNewline: endsWithNewline);
  }
}
