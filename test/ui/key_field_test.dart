import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/models/modifier.dart';
import 'package:keydui/models/remap_warning.dart';
import 'package:keydui/services/key_catalog.dart';
import 'package:keydui/ui/key_field.dart';

const catalog = KeyCatalog(['esc', 'escape', 'f4', 'home', 'left']);
const fallbackCatalog = KeyCatalog([
  'esc',
  'escape',
  'f4',
  'home',
  'left',
], isFallback: true);

Future<void> pumpField(
  WidgetTester tester, {
  required ValueChanged<String> onChanged,
  RemapWarning? Function(String)? warningBuilder,
  ValueChanged<RemapWarning>? onWarningAccepted,
  ValueChanged<Set<Modifier>>? onModifiersCaptured,
  String value = '',
  bool validateAgainstCatalog = true,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: KeyField(
        label: 'To',
        value: value,
        catalog: catalog,
        onChanged: onChanged,
        onModifiersCaptured: onModifiersCaptured,
        warningBuilder: warningBuilder,
        onWarningAccepted: onWarningAccepted,
        validateAgainstCatalog: validateAgainstCatalog,
      ),
    ),
  ),
);

void main() {
  testWidgets('typing filters the catalog and selecting reports the key', (
    tester,
  ) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.enterText(find.byType(TextField), 'f4');
    await tester.pumpAndSettle();
    await tester.tap(find.text('f4').last);
    await tester.pumpAndSettle();
    expect(picked, 'f4');
  });

  testWidgets('listen mode captures a keypress', (tester) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    expect(find.text('Press a key…'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await tester.pumpAndSettle();
    expect(picked, 'f4');
    expect(find.text('Press a key…'), findsNothing);
  });

  testWidgets('cancel leaves listen mode without reporting a key', (
    tester,
  ) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Press a key…'), findsNothing);
  });

  testWidgets('a remapped capture offers the pre-remap key', (tester) async {
    final reported = <String>[];
    final accepted = <RemapWarning>[];
    await pumpField(
      tester,
      onChanged: reported.add,
      warningBuilder: (key) => key == 'home'
          ? const RemapWarning(modifiers: {Modifier.meta}, fromKey: 'left')
          : null,
      onWarningAccepted: accepted.add,
    );
    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(find.text('keyd maps meta+left to this key'), findsOneWidget);
    await tester.tap(find.text('Use meta+left'));
    await tester.pumpAndSettle();

    // The suggestion is `meta` + `left`, and it must arrive as those two
    // parts. Pushing the flattened label back through onChanged would make
    // the key name literally `meta+left`, which serializes to a line keyd
    // rejects with "meta is not a valid key".
    expect(reported, ['home']);
    expect(accepted, hasLength(1));
    expect(accepted.single.modifiers, {Modifier.meta});
    expect(accepted.single.fromKey, 'left');
    expect(find.text('keyd maps meta+left to this key'), findsNothing);
  });

  testWidgets('a modifier held alone is not a capture', (tester) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Press a key…'), findsOneWidget);
  });

  testWidgets('a held modifier is reported alongside the captured key', (
    tester,
  ) async {
    String? picked;
    Set<Modifier>? capturedModifiers;
    await pumpField(
      tester,
      onChanged: (v) => picked = v,
      onModifiersCaptured: (mods) => capturedModifiers = mods,
    );
    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.f4);
    await tester.pumpAndSettle();
    expect(picked, 'f4');
    expect(capturedModifiers, {Modifier.shift});
    await tester.sendKeyUpEvent(LogicalKeyboardKey.f4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  });

  testWidgets('escape while listening is captured, not treated as cancel', (
    tester,
  ) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(picked, 'esc');
    expect(find.text('Press a key…'), findsNothing);
  });

  testWidgets('accepting the suggestion updates the displayed field text once '
      'the consumer applies it', (tester) async {
    final reported = <String>[];
    var currentValue = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => KeyField(
              label: 'From',
              value: currentValue,
              catalog: catalog,
              onChanged: (v) {
                reported.add(v);
                setState(() => currentValue = v);
              },
              warningBuilder: (key) => key == 'home'
                  ? const RemapWarning(
                      modifiers: {Modifier.meta},
                      fromKey: 'left',
                    )
                  : null,
              // A real consumer applies the modifier half to the row's chips
              // and the key half to this field; here only the key half is
              // observable, and it is the BARE key, not `meta+left`.
              onWarningAccepted: (warning) =>
                  setState(() => currentValue = warning.fromKey),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'home',
    );
    await tester.tap(find.text('Use meta+left'));
    await tester.pumpAndSettle();
    expect(reported, ['home']);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'left',
    );
  });

  testWidgets(
    'a rebuild with an unchanged value does not clobber unsubmitted typing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Column(
                children: [
                  KeyField(
                    label: 'To',
                    value: '',
                    catalog: catalog,
                    onChanged: (_) {},
                  ),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Rebuild'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'zz');
      await tester.pump();
      await tester.tap(find.text('Rebuild'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'zz',
      );
    },
  );

  testWidgets(
    'submitting an unrecognised key is rejected with an inline message',
    (tester) async {
      String? picked;
      await pumpField(tester, onChanged: (v) => picked = v);
      await tester.enterText(find.byType(TextField), 'notakey');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(picked, isNull);
      expect(
        find.text("keyd doesn't recognise this key name."),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'submitting a recognised key reports it and clears a prior error',
    (tester) async {
      String? picked;
      await pumpField(tester, onChanged: (v) => picked = v);
      await tester.enterText(find.byType(TextField), 'notakey');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(
        find.text("keyd doesn't recognise this key name."),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'f4');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(picked, 'f4');
      expect(find.text("keyd doesn't recognise this key name."), findsNothing);
    },
  );

  testWidgets('a fallback catalog accepts a typed key it does not list', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyField(
            label: 'To',
            value: '',
            catalog: fallbackCatalog,
            onChanged: (v) => picked = v,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'notinthelist');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(picked, 'notinthelist');
    expect(find.text("keyd doesn't recognise this key name."), findsNothing);
  });

  testWidgets('a listen-mode capture clears a stale unrecognised-entry error', (
    tester,
  ) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.enterText(find.byType(TextField), 'notakey');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text("keyd doesn't recognise this key name."), findsOneWidget);

    await tester.tap(find.byIcon(Icons.keyboard));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f4);
    await tester.pumpAndSettle();

    expect(picked, 'f4');
    expect(find.text("keyd doesn't recognise this key name."), findsNothing);
  });

  testWidgets('a capitalized submission is normalized to lower case', (
    tester,
  ) async {
    String? picked;
    await pumpField(tester, onChanged: (v) => picked = v);
    await tester.enterText(find.byType(TextField), 'F4');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(picked, 'f4');
    expect(find.text("keyd doesn't recognise this key name."), findsNothing);
  });

  testWidgets('a to-field (validateAgainstCatalog: false) preserves case and '
      'accepts a modifier-prefixed action', (tester) async {
    String? picked;
    await pumpField(
      tester,
      onChanged: (v) => picked = v,
      validateAgainstCatalog: false,
    );
    await tester.enterText(find.byType(TextField), 'S-home');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(picked, 'S-home');
    expect(find.text("keyd doesn't recognise this key name."), findsNothing);
  });

  testWidgets(
    'a to-field (validateAgainstCatalog: false) accepts an action the '
    'catalog does not list',
    (tester) async {
      String? picked;
      await pumpField(
        tester,
        onChanged: (v) => picked = v,
        validateAgainstCatalog: false,
      );
      await tester.enterText(find.byType(TextField), 'macro(a b)');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(picked, 'macro(a b)');
      expect(find.text("keyd doesn't recognise this key name."), findsNothing);
    },
  );
}
