import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/mapping_row.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/services/keyd_config_parser.dart';

const sample = '''# a comment

[ids]
*

[meta]
left = home
right = end
''';

String applyRows(String text, List<MappingRow> rows) =>
    serializeKeydConfig(parseKeydConfig(text).withRows(rows));

void main() {
  test('editing a row rewrites only that line', () {
    final config = parseKeydConfig(sample);
    final rows = config.rows.toList();
    rows[0] = rows[0].copyWith(toKey: 'pageup');
    expect(serializeKeydConfig(config.withRows(rows)), '''# a comment

[ids]
*

[meta]
left = pageup
right = end
''');
  });

  test('deleting the last row of a section removes the header', () {
    final rows = parseKeydConfig(sample).rows.toList()..removeRange(0, 2);
    expect(applyRows(sample, rows), '''# a comment

[ids]
*

''');
  });

  test('a new modifier group appends a new section', () {
    final rows = parseKeydConfig(sample).rows.toList()
      ..add(const MappingRow(modifiers: {}, fromKey: 'capslock', toKey: 'esc'));
    expect(applyRows(sample, rows), '''# a comment

[ids]
*

[meta]
left = home
right = end

[main]
capslock = esc
''');
  });

  test('passthrough lines inside a section survive an edit', () {
    const text = '[main]\n# keep me\ncapslock = esc\n';
    final rows = parseKeydConfig(text).rows.toList();
    expect(
      applyRows(text, [rows.single.copyWith(toKey: 'tab')]),
      '[main]\n# keep me\ncapslock = tab\n',
    );
  });

  test('adding to an existing section appends inside it', () {
    final rows = parseKeydConfig(sample).rows.toList()
      ..add(
        const MappingRow(
          modifiers: {Modifier.meta},
          fromKey: 'up',
          toKey: 'pageup',
        ),
      );
    expect(applyRows(sample, rows), contains('right = end\nup = pageup\n'));
  });

  test(
    'new section appends after passthrough blocks when no mapping exists',
    () {
      const text = '[ids]\n*\n';
      final rows = <MappingRow>[
        const MappingRow(modifiers: {}, fromKey: 'capslock', toKey: 'esc'),
      ];
      expect(applyRows(text, rows), '''[ids]
*

[main]
capslock = esc
''');
    },
  );

  test('comments between rows survive unedited round-trip', () {
    const text = '[main]\nleft = home\n# a note\nright = end\n';
    final config = parseKeydConfig(text);
    expect(serializeKeydConfig(config.withRows(config.rows)), text);
  });
}
