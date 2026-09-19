import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/services/key_labels.dart';

void main() {
  group('keyLabel', () {
    test('names a key the way the keyboard does', () {
      expect(keyLabel('home'), 'Home');
      expect(keyLabel('f4'), 'F4');
      expect(keyLabel('left'), 'Left Arrow');
      expect(keyLabel('pageup'), 'Page Up');
      expect(keyLabel('capslock'), 'Caps Lock');
      expect(keyLabel('leftmeta'), 'Left Super');
      expect(keyLabel('sysrq'), 'Print Screen');
    });

    test('shows a punctuation key as the character it types', () {
      expect(keyLabel('comma'), ',');
      expect(keyLabel('leftbrace'), '[');
      expect(keyLabel('grave'), '`');
    });

    test('upper-cases a single letter', () {
      expect(keyLabel('a'), 'A');
      expect(keyLabel('z'), 'Z');
    });

    test('leaves a digit alone', () {
      expect(keyLabel('7'), '7');
    });

    test('capitalizes an unlisted key rather than dropping it', () {
      expect(keyLabel('brightnessup'), 'Brightnessup');
      expect(keyLabel('102nd'), '102nd');
    });

    test('an empty name has an empty label', () {
      expect(keyLabel(''), '');
    });
  });

  group('keydNameForLabel', () {
    test('reverses a display label', () {
      expect(keydNameForLabel('Left Arrow'), 'left');
      expect(keydNameForLabel('Page Up'), 'pageup');
      expect(keydNameForLabel('Print Screen'), 'sysrq');
      expect(keydNameForLabel('['), 'leftbrace');
    });

    test('accepts a keyd name typed directly', () {
      expect(keydNameForLabel('pageup'), 'pageup');
      expect(keydNameForLabel('home'), 'home');
    });

    test('ignores case and surrounding whitespace', () {
      expect(keydNameForLabel('  left arrow '), 'left');
      expect(keydNameForLabel('F4'), 'f4');
    });

    test('falls back to the lower-cased input for an unknown label', () {
      expect(keydNameForLabel('Notakey'), 'notakey');
    });

    test('round-trips every labelled key', () {
      for (final name in labelledKeys) {
        expect(keydNameForLabel(keyLabel(name)), name, reason: name);
      }
    });
  });

  group('knownKeydNameForLabel', () {
    test('resolves a display label', () {
      expect(knownKeydNameForLabel('Page Up'), 'pageup');
    });

    test('returns null for anything that is not a label', () {
      // A to-field submits keyd actions through this; `S-home` must not be
      // mangled into `s-home`, and `macro(a b)` must not be touched at all.
      expect(knownKeydNameForLabel('S-home'), isNull);
      expect(knownKeydNameForLabel('macro(a b)'), isNull);
      expect(knownKeydNameForLabel('notakey'), isNull);
    });
  });

  group('keySearchQuery', () {
    test('drops spaces so a two-word label finds its key', () {
      expect(keySearchQuery('Page Up'), 'pageup');
      expect(keySearchQuery('page u'), 'pageu');
    });

    test('leaves a directly typed keyd name searchable', () {
      expect(keySearchQuery('pageu'), 'pageu');
      expect(keySearchQuery(''), '');
    });
  });

  group('modifierLabel', () {
    test('names modifiers the way the keyboard does', () {
      expect(modifierLabel(Modifier.control), 'Ctrl');
      expect(modifierLabel(Modifier.alt), 'Alt');
      expect(modifierLabel(Modifier.meta), 'Super');
      expect(modifierLabel(Modifier.shift), 'Shift');
    });
  });

  group('chordLabel', () {
    test('joins modifiers and the key in canonical order', () {
      expect(
        chordLabel(const {Modifier.alt, Modifier.control}, 'f4'),
        'Ctrl + Alt + F4',
      );
    });

    test('a bare key has no separator', () {
      expect(chordLabel(const {}, 'home'), 'Home');
    });

    test('modifiers with no key read as a partial chord', () {
      expect(chordLabel(const {Modifier.shift}, ''), 'Shift + …');
    });

    test('nothing at all is empty', () {
      expect(chordLabel(const {}, ''), '');
    });
  });
}
