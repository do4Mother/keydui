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

  group('duplicate section headers', () {
    // `keyd check` accepts a file that opens the same section twice.
    const doubled = '[main]\na = b\nc = d\n\n[main]\ne = f\n';

    test('an unedited round-trip through withRows is byte identical', () {
      final config = parseKeydConfig(doubled);
      expect(config.rows, hasLength(3));
      expect(serializeKeydConfig(config.withRows(config.rows)), doubled);
    });

    test('editing a row in the second instance rewrites only that line', () {
      final config = parseKeydConfig(doubled);
      final rows = config.rows.toList();
      rows[2] = rows[2].copyWith(toKey: 'g');
      expect(
        serializeKeydConfig(config.withRows(rows)),
        '[main]\na = b\nc = d\n\n[main]\ne = g\n',
      );
    });

    test('a row added to a repeated section lands in the last instance', () {
      final config = parseKeydConfig(doubled);
      final rows = config.rows.toList()
        ..add(const MappingRow(modifiers: {}, fromKey: 'x', toKey: 'y'));
      expect(
        serializeKeydConfig(config.withRows(rows)),
        '[main]\na = b\nc = d\n\n[main]\ne = f\nx = y\n',
      );
    });
  });

  test('adding then removing a section leaves no blank line behind', () {
    const text = '[meta]\nleft = home\n';
    final withNewSection = applyRows(text, [
      ...parseKeydConfig(text).rows,
      const MappingRow(modifiers: {}, fromKey: 'capslock', toKey: 'esc'),
    ]);
    expect(withNewSection, '[meta]\nleft = home\n\n[main]\ncapslock = esc\n');

    // Reopening that file and deleting the added row must give the original
    // back, not the original plus an orphaned blank line.
    final reopened = parseKeydConfig(withNewSection);
    final rows = reopened.rows.where((r) => r.fromKey != 'capslock').toList();
    expect(serializeKeydConfig(reopened.withRows(rows)), text);
  });

  test('a blank line trailing real content is not eaten by a dropped '
      'section', () {
    const text = '# a note\n\n[meta]\nleft = home\n';
    expect(applyRows(text, const []), '# a note\n\n');
  });

  test('the shipped config survives an unedited open-and-save', () {
    // The exact shape of the author's own /etc/keyd/default.conf, including
    // its missing trailing newline. `serialize(parse(x)) == x` is covered in
    // the parser test; this is the path that actually runs when the user
    // presses Save.
    const real =
        '# Meta+Left/Right -> Home/End (macOS-style line navigation)\n'
        '# Shift is passed through, so Shift+Meta+Left selects to start of line.\n'
        '\n'
        '[ids]\n'
        '*\n'
        '\n'
        '[meta]\n'
        'left = home\n'
        'right = end\n'
        '\n'
        '[meta+shift]\n'
        'left = S-home\n'
        'right = S-end';
    final config = parseKeydConfig(real);
    expect(serializeKeydConfig(config.withRows(config.rows)), real);
  });

  test('comments between rows survive unedited round-trip', () {
    const text = '[main]\nleft = home\n# a note\nright = end\n';
    final config = parseKeydConfig(text);
    expect(serializeKeydConfig(config.withRows(config.rows)), text);
  });
}
