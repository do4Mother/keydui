import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/key_action.dart';
import 'package:keydui/models/modifier.dart';

void main() {
  group('parse', () {
    test('a bare key name has no modifiers', () {
      final action = KeyAction.parse('home');
      expect(action.isAdvanced, isFalse);
      expect(action.modifiers, isEmpty);
      expect(action.key, 'home');
    });

    test('a single prefix is decoded', () {
      final action = KeyAction.parse('S-home');
      expect(action.isAdvanced, isFalse);
      expect(action.modifiers, {Modifier.shift});
      expect(action.key, 'home');
    });

    test('stacked prefixes are decoded in any order', () {
      expect(KeyAction.parse('C-A-f4').modifiers, {
        Modifier.control,
        Modifier.alt,
      });
      expect(KeyAction.parse('A-C-f4').modifiers, {
        Modifier.control,
        Modifier.alt,
      });
      expect(KeyAction.parse('M-S-left').modifiers, {
        Modifier.meta,
        Modifier.shift,
      });
    });

    test('an empty action is simple and empty, not advanced', () {
      final action = KeyAction.parse('   ');
      expect(action.isAdvanced, isFalse);
      expect(action.modifiers, isEmpty);
      expect(action.key, '');
    });

    test('surrounding whitespace is ignored', () {
      expect(KeyAction.parse('  S-home  ').key, 'home');
    });

    // AltGr has no chip in [Modifier], so a `G-` action has no faithful
    // chip representation and must stay editable as raw text rather than
    // silently losing its prefix.
    test('an altgr prefix is advanced', () {
      final action = KeyAction.parse('G-4');
      expect(action.isAdvanced, isTrue);
      expect(action.raw, 'G-4');
    });

    test('a macro, layer or command expression is advanced', () {
      for (final text in [
        'macro(a b)',
        'layer(nav)',
        'command(systemctl suspend)',
        'overload(nav, esc)',
        'timeout(esc, 200, leftcontrol)',
      ]) {
        final action = KeyAction.parse(text);
        expect(action.isAdvanced, isTrue, reason: text);
        expect(action.raw, text);
      }
    });

    test('an unrecognised prefix is advanced rather than a key named X-f4', () {
      final action = KeyAction.parse('X-f4');
      expect(action.isAdvanced, isTrue);
      expect(action.raw, 'X-f4');
    });

    test('a prefix with nothing after it is advanced', () {
      expect(KeyAction.parse('S-').isAdvanced, isTrue);
    });

    test('a multi-word action is advanced', () {
      expect(KeyAction.parse('a b').isAdvanced, isTrue);
    });

    test('a lower-case prefix is not a keyd prefix', () {
      // keyd's prefixes are upper case; `s-home` is not `S-home`, so it is
      // not silently reinterpreted as Shift+Home.
      expect(KeyAction.parse('s-home').isAdvanced, isTrue);
    });
  });

  group('format', () {
    test('a bare key formats without a prefix', () {
      expect(KeyAction.simple(const {}, 'home').format(), 'home');
    });

    test('modifiers format in keyd canonical order', () {
      expect(
        KeyAction.simple(const {
          Modifier.shift,
          Modifier.control,
          Modifier.meta,
          Modifier.alt,
        }, 'f4').format(),
        'C-A-M-S-f4',
      );
    });

    test('an empty key formats to an empty action, not a dangling prefix', () {
      expect(KeyAction.simple(const {Modifier.shift}, '').format(), '');
    });

    test('an advanced action formats back to its raw text', () {
      expect(KeyAction.parse('macro(a b)').format(), 'macro(a b)');
    });

    test('parse and format round-trip', () {
      for (final text in ['home', 'S-home', 'C-A-f4', 'macro(a b)', 'G-4']) {
        expect(KeyAction.parse(text).format(), text, reason: text);
      }
    });

    test('a non-canonical order is normalized on round-trip', () {
      expect(KeyAction.parse('A-C-f4').format(), 'C-A-f4');
    });
  });

  group('compose', () {
    test('chips and a bare key combine', () {
      expect(
        KeyAction.compose(const {Modifier.control, Modifier.alt}, 'f4'),
        'C-A-f4',
      );
    });

    test('a key typed with its own prefix merges with the chips', () {
      expect(KeyAction.compose(const {Modifier.control}, 'S-home'), 'C-S-home');
    });

    // Prefixing an expression -- `C-macro(a b)` -- is not valid keyd, so an
    // advanced entry replaces the chord instead of being decorated by it.
    test('an advanced key typed into the field discards the chips', () {
      expect(
        KeyAction.compose(const {Modifier.control}, 'macro(a b)'),
        'macro(a b)',
      );
    });

    test('an empty key yields an empty action', () {
      expect(KeyAction.compose(const {Modifier.control}, ''), '');
    });
  });
}
