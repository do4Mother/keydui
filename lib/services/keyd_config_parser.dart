import '../models/keyd_config.dart';
import '../models/mapping_row.dart';
import '../models/modifier.dart';

final _header = RegExp(r'^\s*\[([^\]]*)\]\s*$');
final _mapping = RegExp(r'^\s*([^=\s]+)\s*=\s*(.*?)\s*$');

KeydConfig parseKeydConfig(String text) {
  final endsWithNewline = text.isEmpty || text.endsWith('\n');
  final lines = text.split('\n');
  if (endsWithNewline && lines.isNotEmpty) lines.removeLast();

  final elements = <ConfigElement>[];
  var passthrough = <String>[];
  MappingSection? section;

  void flushPassthrough() {
    if (passthrough.isNotEmpty) {
      elements.add(PassthroughBlock(passthrough));
      passthrough = <String>[];
    }
  }

  for (final line in lines) {
    final header = _header.firstMatch(line);
    if (header != null) {
      final modifiers = Modifier.parseSectionName(header.group(1)!);
      if (modifiers != null) {
        flushPassthrough();
        section = MappingSection(
          modifiers: modifiers,
          headerLine: line,
          entries: <SectionEntry>[],
        );
        elements.add(section);
      } else {
        // A section the UI does not model; everything until the next header
        // is passthrough.
        section = null;
        passthrough.add(line);
      }
      continue;
    }

    if (section == null) {
      passthrough.add(line);
      continue;
    }

    final mapping = _mapping.firstMatch(line);
    if (mapping != null && mapping.group(2)!.isNotEmpty) {
      section.entries.add(RowEntry(MappingRow(
        modifiers: section.modifiers,
        fromKey: mapping.group(1)!,
        toKey: mapping.group(2)!,
        rawLine: line,
      )));
    } else {
      section.entries.add(RawEntry(line));
    }
  }
  flushPassthrough();

  return KeydConfig(elements, endsWithNewline: endsWithNewline);
}

String serializeKeydConfig(KeydConfig config) {
  final lines = <String>[];
  for (final element in config.elements) {
    switch (element) {
      case PassthroughBlock():
        lines.addAll(element.lines);
      case MappingSection(:final headerLine, :final entries):
        lines.add(headerLine);
        for (final entry in entries) {
          lines.add(switch (entry) {
            RowEntry(:final row) => row.render(),
            RawEntry(:final line) => line,
          });
        }
    }
  }
  final text = lines.join('\n');
  return config.endsWithNewline && text.isNotEmpty ? '$text\n' : text;
}
