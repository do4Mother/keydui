import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/services/key_catalog.dart';
import 'package:keydui/services/process_runner.dart';

import '../support/fake_process_runner.dart';

void main() {
  test('parses keyd list-keys output', () {
    final catalog = KeyCatalog.parse('esc\nescape\n\nleftmeta\nesc\n');
    expect(catalog.keys, ['esc', 'escape', 'leftmeta']);
    expect(catalog.contains('leftmeta'), isTrue);
    expect(catalog.contains('nope'), isFalse);
  });

  test('loads from keyd', () async {
    final runner = FakeProcessRunner({
      'keyd': const ProcessOutcome(exitCode: 0, stdout: 'esc\nf4\n'),
    });
    final catalog = await KeyCatalog.load(runner);
    expect(catalog.keys, ['esc', 'f4']);
    expect(catalog.isFallback, isFalse);
    expect(runner.calls.single, ['keyd', 'list-keys']);
  });

  test('falls back when keyd is missing', () async {
    final catalog = await KeyCatalog.load(FakeProcessRunner({}));
    expect(catalog.isFallback, isTrue);
    expect(catalog.contains('f4'), isTrue);
    expect(catalog.contains('capslock'), isTrue);
  });

  test('search puts prefix matches first', () {
    final catalog = KeyCatalog.parse('leftmeta\nescape\nesc\nrightmeta\n');
    expect(catalog.search('esc'), ['escape', 'esc']);
    expect(catalog.search('meta'), ['leftmeta', 'rightmeta']);
    expect(catalog.search(''), ['leftmeta', 'escape', 'esc', 'rightmeta']);
  });
}
