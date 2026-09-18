import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/modifier.dart';

void main() {
  test('main section for no modifiers', () {
    expect(Modifier.sectionName({}), 'main');
    expect(Modifier.parseSectionName('main'), isEmpty);
  });

  test('section names use canonical order', () {
    expect(Modifier.sectionName({Modifier.shift, Modifier.meta}), 'meta+shift');
    expect(
      Modifier.sectionName({Modifier.shift, Modifier.control}),
      'control+shift',
    );
  });

  test('parses modifier section names in any order', () {
    expect(Modifier.parseSectionName('meta+shift'), {
      Modifier.meta,
      Modifier.shift,
    });
    expect(Modifier.parseSectionName('shift+meta'), {
      Modifier.meta,
      Modifier.shift,
    });
    expect(Modifier.parseSectionName(' meta '), {Modifier.meta});
  });

  test('returns null for non-modifier sections', () {
    expect(Modifier.parseSectionName('ids'), isNull);
    expect(Modifier.parseSectionName('nav'), isNull);
    expect(Modifier.parseSectionName('meta+nav'), isNull);
    expect(Modifier.parseSectionName(''), isNull);
  });
}
