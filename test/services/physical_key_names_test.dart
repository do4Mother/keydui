// test/services/physical_key_names_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/services/physical_key_names.dart';

void main() {
  test('maps letters and digits', () {
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.keyA), 'a');
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.keyZ), 'z');
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.digit1), '1');
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.digit0), '0');
  });

  test('maps function and navigation keys', () {
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.f4), 'f4');
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.f12), 'f12');
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.arrowLeft), 'left');
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.pageUp), 'pageup');
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.capsLock), 'capslock');
  });

  test('maps punctuation to keyd names', () {
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.period), 'dot');
    expect(
      keydNameForPhysicalKey(PhysicalKeyboardKey.bracketLeft),
      'leftbrace',
    );
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.backquote), 'grave');
  });

  test('identifies modifier keys', () {
    expect(modifierForPhysicalKey(PhysicalKeyboardKey.metaLeft), Modifier.meta);
    expect(
      modifierForPhysicalKey(PhysicalKeyboardKey.shiftRight),
      Modifier.shift,
    );
    expect(
      modifierForPhysicalKey(PhysicalKeyboardKey.controlLeft),
      Modifier.control,
    );
    expect(modifierForPhysicalKey(PhysicalKeyboardKey.keyA), isNull);
  });

  test('returns null for keys with no keyd name', () {
    expect(keydNameForPhysicalKey(PhysicalKeyboardKey.gameButton1), isNull);
  });
}
