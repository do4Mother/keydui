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
class ChordField extends StatelessWidget {
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
  /// are always reported together -- see the note in [build].
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
  Widget build(BuildContext context) {
    // A capture fires `onModifiersCaptured` and then `onChanged`
    // synchronously, before this widget rebuilds, and both close over the
    // same build's [modifiers]. Reporting them separately would make the
    // second call derive from the stale pre-capture chord and silently drop
    // the first call's half, so the modifiers are stashed here and folded
    // into the single update the key capture triggers.
    Set<Modifier>? capturedModifiers;

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
                width: _indent,
                child: Text(label, style: theme.textTheme.labelLarge),
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
                        selected: modifiers.contains(modifier),
                        visualDensity: VisualDensity.compact,
                        onSelected: (selected) {
                          final next = modifiers.toSet();
                          selected ? next.add(modifier) : next.remove(modifier);
                          onChanged(next, keyName);
                        },
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
                value: keyName,
                catalog: catalog,
                humanLabels: true,
                validateAgainstCatalog: validateAgainstCatalog,
                warningBuilder: warningBuilder,
                onWarningAccepted: (warning) =>
                    onChanged(warning.modifiers, warning.fromKey),
                onModifiersCaptured: (mods) => capturedModifiers = mods,
                onChanged: (key) =>
                    onChanged(capturedModifiers ?? modifiers, key),
              ),
            ),
          ],
        ),
        if (footnote != null)
          Padding(
            padding: const EdgeInsets.only(left: _indent, top: 2),
            child: Text(
              footnote!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
