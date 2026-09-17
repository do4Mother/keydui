import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/keyd_config.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/services/keyd_config_parser.dart';

const sample = '''
# Meta+Left/Right -> Home/End (macOS-style line navigation)
# Shift is passed through, so Shift+Meta+Left selects to start of line.

[ids]
*

[meta]
left = home
right = end

[meta+shift]
left = S-home
right = S-end
''';

void main() {
  test('round trip is byte identical', () {
    expect(serializeKeydConfig(parseKeydConfig(sample)), sample);
  });

  test('round trip preserves layers and odd spacing', () {
    const text = '[main]\ncapslock   =  esc\n\n[nav]\nh = left\n';
    expect(serializeKeydConfig(parseKeydConfig(text)), text);
  });

  test('extracts rows with their modifiers', () {
    final rows = parseKeydConfig(sample).rows;
    expect(rows, hasLength(4));
    expect(rows[0].modifiers, {Modifier.meta});
    expect(rows[0].fromKey, 'left');
    expect(rows[0].toKey, 'home');
    expect(rows[3].modifiers, {Modifier.meta, Modifier.shift});
    expect(rows[3].toKey, 'S-end');
  });

  test('non-modifier sections become passthrough, not rows', () {
    final config = parseKeydConfig('[nav]\nh = left\n');
    expect(config.rows, isEmpty);
    expect(config.elements.single, isA<PassthroughBlock>());
  });

  test('unrecognized line inside a mapping section survives', () {
    const text = '[main]\ncapslock = esc\nsomething odd here\n';
    final config = parseKeydConfig(text);
    expect(config.rows, hasLength(1));
    expect(serializeKeydConfig(config), text);
  });

  test('a layer() binding is an ordinary row', () {
    const text = '[main]\ncapslock = layer(nav)\n';
    final config = parseKeydConfig(text);
    expect(config.rows.single.toKey, 'layer(nav)');
    expect(serializeKeydConfig(config), text);
  });

  test('handles a file with no trailing newline', () {
    const text = '[main]\ncapslock = esc';
    expect(serializeKeydConfig(parseKeydConfig(text)), text);
  });

  test('round trip for a single blank line', () {
    const text = '\n';
    expect(serializeKeydConfig(parseKeydConfig(text)), text);
  });
}
