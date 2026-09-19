import 'package:flutter/material.dart';

import '../models/modifier.dart';
import '../models/remap_warning.dart';
import '../services/key_catalog.dart';
import '../services/key_labels.dart';
import 'key_field.dart';

/// One half of a mapping -- modifiers plus a key -- entered as chips and a
/// key field.
///
/// Both halves of a row are built from this. The trigger side and the action
/// side differ only in how their chord is stored (a section header versus a
/// `C-A-f4` prefix), and that difference belongs to the row, not here: this
/// reports a chord and never a keyd string.
class ChordField extends StatefulWidget {
  const ChordField({
    super.key,
    required this.label,
    required this.modifiers,
    required this.keyName,
    required this.catalog,
    required this.onChanged,
    this.validateAgainstCatalog = true,
    this.warningBuilder,
    this.footnote,
  });

  final String label;
  final Set<Modifier> modifiers;

  /// The bare keyd key name, e.g. `pageup`. Shown as `Page Up`.
  final String keyName;
  final KeyCatalog catalog;

  /// Called with the whole chord whenever either half changes. Both halves
  /// are always reported together -- a capture reports both halves at once.
  final void Function(Set<Modifier> modifiers, String key) onChanged;

  /// Passed through to [KeyField]; false for an action field, whose text may
  /// be a `macro(...)` expression the key catalog never lists.
  final bool validateAgainstCatalog;

  final RemapWarning? Function(String capturedKey)? warningBuilder;

  /// Small print under the field, used to show the keyd text this chord
  /// will be written as.
  final String? footnote;

  static const _indent = 56.0;

  @override
  State<ChordField> createState() => _ChordFieldState();
}

class _ChordFieldState extends State<ChordField> {
  /// Chips clicked while there is no key to carry them, or null once the
  /// parent can hold them itself.
  ///
  /// An action with no key has nowhere to keep its modifiers: keyd writes a
  /// chord as prefixes on a key, so `Ctrl` alone is not a line and the row
  /// reports it back as the empty action it was. Without this the chip would
  /// spring straight back off under the user's cursor, and the only way to
  /// set a modifier would be to hold it during a capture. Remembering it
  /// here lets the chips be clicked in any order, and the first key entered
  /// picks them up.
  Set<Modifier>? _pendingModifiers;

  /// The modifiers held during a capture, stashed between
  /// [KeyField.onModifiersCaptured] and the [KeyField.onChanged] that
  /// follows it synchronously so the chord is reported as one update rather
  /// than as two, the second of which would derive from the stale chord and
  /// drop the first's half.
  Set<Modifier>? _capturedModifiers;

  Set<Modifier> get _modifiers => _pendingModifiers ?? widget.modifiers;

  @override
  void didUpdateWidget(covariant ChordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Once there is a key, the chord round-trips through the parent and the
    // local memory would only shadow it.
    if (widget.keyName.isNotEmpty) _pendingModifiers = null;
  }

  void _onChipToggled(Modifier modifier, bool selected) {
    final next = _modifiers.toSet();
    selected ? next.add(modifier) : next.remove(modifier);
    setState(() {
      _pendingModifiers = widget.keyName.isEmpty ? next : null;
    });
    widget.onChanged(next, widget.keyName);
  }

  void _onKeyChanged(String key) {
    final modifiers = _capturedModifiers ?? _modifiers;
    _capturedModifiers = null;
    // The remembered chips are deliberately left alone here and dropped in
    // [didUpdateWidget] once the new key comes back: submitting text can
    // call this twice in one handler -- once for the highlighted
    // autocomplete option and once for the submission -- and clearing them
    // now would make the second call, which still sees the pre-update
    // [widget], report the key without its modifiers.
    widget.onChanged(modifiers, key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: ChordField._indent,
                child: Text(widget.label, style: theme.textTheme.labelLarge),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final modifier in Modifier.values)
                      FilterChip(
                        label: Text(modifierLabel(modifier)),
                        selected: _modifiers.contains(modifier),
                        visualDensity: VisualDensity.compact,
                        onSelected: (selected) =>
                            _onChipToggled(modifier, selected),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: KeyField(
                label: 'Key',
                value: widget.keyName,
                catalog: widget.catalog,
                humanLabels: true,
                validateAgainstCatalog: widget.validateAgainstCatalog,
                warningBuilder: widget.warningBuilder,
                onWarningAccepted: (warning) =>
                    widget.onChanged(warning.modifiers, warning.fromKey),
                onModifiersCaptured: (mods) => _capturedModifiers = mods,
                onChanged: _onKeyChanged,
              ),
            ),
          ],
        ),
        if (widget.footnote != null)
          Padding(
            padding: const EdgeInsets.only(left: ChordField._indent, top: 2),
            child: Text(
              widget.footnote!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
