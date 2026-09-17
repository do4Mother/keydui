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
}
