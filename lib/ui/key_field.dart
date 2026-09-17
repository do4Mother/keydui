import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/modifier.dart';
import '../services/key_catalog.dart';
import '../services/physical_key_names.dart';

class KeyField extends StatefulWidget {
  const KeyField({
    super.key,
    required this.label,
    required this.value,
    required this.catalog,
    required this.onChanged,
    this.onModifiersCaptured,
    this.warningBuilder,
  });

  final String label;
  final String value;
  final KeyCatalog catalog;
  final ValueChanged<String> onChanged;

  /// Called with the modifiers held during a listen capture (from-fields only).
  final ValueChanged<Set<Modifier>>? onModifiersCaptured;

  /// Given a captured key, returns a warning label or null.
  final String? Function(String capturedKey)? warningBuilder;

  @override
  State<KeyField> createState() => _KeyFieldState();
}

class _KeyFieldState extends State<KeyField> {
  final _listenFocus = FocusNode();
  bool _listening = false;
  String? _warning;

  @override
  void dispose() {
    _listenFocus.dispose();
    super.dispose();
  }

  void _startListening() {
    setState(() {
      _listening = true;
      _warning = null;
    });
  }

  void _cancelListening() {
    setState(() => _listening = false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;

    final modifier = modifierForPhysicalKey(event.physicalKey);
    if (modifier != null) {
      // Wait for a non-modifier key; modifiers alone are not a capture.
      return KeyEventResult.handled;
    }

    final name = keydNameForPhysicalKey(event.physicalKey);
    if (name == null) return KeyEventResult.handled;

    final held = <Modifier>{
      for (final key in HardwareKeyboard.instance.physicalKeysPressed)
        if (modifierForPhysicalKey(key) != null) modifierForPhysicalKey(key)!,
    };
    widget.onModifiersCaptured?.call(held);
    widget.onChanged(name);

    setState(() {
      _listening = false;
      _warning = widget.warningBuilder?.call(name);
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (_listening) {
      return Focus(
        focusNode: _listenFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Row(
          children: [
            const Expanded(child: Text('Press a key…')),
            TextButton(
              onPressed: _cancelListening,
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Autocomplete<String>(
                initialValue: TextEditingValue(text: widget.value),
                optionsBuilder: (value) => widget.catalog.search(value.text),
                onSelected: widget.onChanged,
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) =>
                        TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: widget.label,
                    isDense: true,
                  ),
                  onSubmitted: (text) {
                    widget.onChanged(text.trim());
                    onFieldSubmitted();
                  },
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.headphones),
              tooltip: 'Press a key to capture it',
              onPressed: _startListening,
            ),
          ],
        ),
        if (_warning != null)
          Row(
            children: [
              Flexible(
                child: Text(
                  'keyd maps $_warning to this key',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.onChanged(_warning!);
                  setState(() => _warning = null);
                },
                child: Text('Use $_warning'),
              ),
            ],
          ),
      ],
    );
  }
}
