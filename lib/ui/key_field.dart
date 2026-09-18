import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/modifier.dart';
import '../models/remap_warning.dart';
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
    this.onWarningAccepted,
    this.validateAgainstCatalog = true,
  });

  final String label;

  /// The current keyd key name shown in the field.
  ///
  /// The field owns a [TextEditingController] internally rather than handing
  /// [Autocomplete] a fresh `initialValue` on every build, so this is not
  /// applied "for free" the way a plain [TextField]'s initial text would be.
  /// Whenever this differs from the previous build — for example because the
  /// parent applied the warning row's "Use `<label>`" suggestion, which calls
  /// [onChanged] without any change to listen mode — `didUpdateWidget` copies
  /// the new text into the controller. It is left alone on every other
  /// rebuild, since [value] only changes in response to [onChanged] and not
  /// on each keystroke, so a rebuild mid-typing never clobbers unsubmitted
  /// text.
  final String value;
  final KeyCatalog catalog;
  final ValueChanged<String> onChanged;

  /// Called with the modifiers held during a listen capture (from-fields only).
  ///
  /// Contract: within a single capture this is always called first and is
  /// always followed SYNCHRONOUSLY by [onChanged] with the captured key, in
  /// the same event handler and before this widget rebuilds -- so a consumer
  /// may stash the modifiers here and fold them into the row it builds in
  /// [onChanged] rather than emitting two separate updates.
  final ValueChanged<Set<Modifier>>? onModifiersCaptured;

  /// Given a captured key, returns the mapping that already produces it, or
  /// null. The result is structured (modifiers + bare key), not a flattened
  /// `meta+left` label, so accepting it can update a row's modifiers and its
  /// key separately; [RemapWarning.label] renders the display text.
  final RemapWarning? Function(String capturedKey)? warningBuilder;

  /// Called when the user accepts the warning's "Use `<label>`" suggestion.
  /// The consumer applies BOTH halves -- the modifiers and the key -- to the
  /// row; [onChanged] is deliberately not used for this, because the key
  /// field alone cannot express the modifier half.
  final ValueChanged<RemapWarning>? onWarningAccepted;

  /// Whether manually typed, submitted text is checked against [catalog]
  /// and lower-cased before reaching [onChanged].
  ///
  /// This is correct for a *from* field, whose value is always a bare key
  /// name — `catalog` (from `keyd list-keys`) is authoritative for those,
  /// modulo [KeyCatalog.isFallback]. It is wrong for a *to* field, whose
  /// value is a keyd **action**: it may carry an upper-case modifier prefix
  /// (`S-home`, `C-M-tab`) that must not be lower-cased, or be a
  /// `macro(...)` / `layer(...)` expression that `list-keys` never
  /// enumerates. Defaults to `true` (from-field behaviour); pass `false` for
  /// a to-field and let `keyd check` at save time be the gate instead. The
  /// typeahead dropdown still offers catalog suggestions either way — only
  /// the rejection and case-folding on manual submission are affected.
  final bool validateAgainstCatalog;

  @override
  State<KeyField> createState() => _KeyFieldState();
}

class _KeyFieldState extends State<KeyField> {
  static const _unrecognizedKeyMessage =
      "keyd doesn't recognise this key name.";

  final _listenFocus = FocusNode();
  final _fieldFocus = FocusNode();
  late final _controller = TextEditingController(text: widget.value);
  bool _listening = false;
  RemapWarning? _warning;
  String? _entryError;

  @override
  void didUpdateWidget(covariant KeyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && _controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _listenFocus.dispose();
    _fieldFocus.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Whether [text] is acceptable as a manually typed (not autocompleted)
  /// key name. A fallback catalog only covers the common 104-key set, so it
  /// is not authoritative and anything typed is accepted; a real catalog
  /// from `keyd list-keys` is authoritative and typos are rejected.
  bool _isKnownKey(String text) =>
      widget.catalog.isFallback || widget.catalog.contains(text);

  void _onFieldTextChanged(String text) {
    if (!widget.validateAgainstCatalog) return;
    if (_entryError != null && _isKnownKey(text.trim().toLowerCase())) {
      setState(() => _entryError = null);
    }
  }

  void _onFieldSubmitted(String text, VoidCallback onFieldSubmitted) {
    final trimmed = text.trim();
    if (!widget.validateAgainstCatalog) {
      // A to-field's value is a keyd action, not a bare key name: it may
      // carry an upper-case modifier prefix (`S-home`) or be a macro/layer
      // expression the catalog never enumerates. Accept it as typed and let
      // `keyd check` at save time be the gate.
      if (trimmed.isNotEmpty) widget.onChanged(trimmed);
      onFieldSubmitted();
      return;
    }

    // keyd key names are lower case; normalize what was typed so that
    // capitalization (e.g. typing "F4" on a keyboard with no F-row, where
    // typing is the only way in) doesn't get rejected as unrecognised.
    final normalized = trimmed.toLowerCase();
    if (normalized.isNotEmpty) {
      if (_isKnownKey(normalized)) {
        setState(() => _entryError = null);
        widget.onChanged(normalized);
      } else {
        setState(() => _entryError = _unrecognizedKeyMessage);
      }
    }
    onFieldSubmitted();
  }

  void _startListening() {
    setState(() {
      _listening = true;
      _warning = null;
      _entryError = null;
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
      _entryError = null;
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
                textEditingController: _controller,
                focusNode: _fieldFocus,
                optionsBuilder: (value) => widget.catalog.search(value.text),
                onSelected: (selection) {
                  setState(() => _entryError = null);
                  widget.onChanged(selection);
                },
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) =>
                        TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: widget.label,
                            isDense: true,
                            errorText: _entryError,
                          ),
                          onChanged: _onFieldTextChanged,
                          onSubmitted: (text) =>
                              _onFieldSubmitted(text, onFieldSubmitted),
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
                  'keyd maps ${_warning!.label} to this key',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.onWarningAccepted?.call(_warning!);
                  setState(() => _warning = null);
                },
                child: Text('Use ${_warning!.label}'),
              ),
            ],
          ),
      ],
    );
  }
}
