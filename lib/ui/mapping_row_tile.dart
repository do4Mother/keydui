import 'package:flutter/material.dart';

import '../models/key_action.dart';
import '../models/mapping_row.dart';
import '../models/remap_warning.dart';
import '../services/key_catalog.dart';
import '../services/key_labels.dart';
import 'chord_field.dart';
import 'key_field.dart';

class MappingRowTile extends StatelessWidget {
  const MappingRowTile({
    super.key,
    required this.row,
    required this.catalog,
    required this.onChanged,
    required this.onDelete,
    this.warningBuilder,
  });

  final MappingRow row;
  final KeyCatalog catalog;
  final ValueChanged<MappingRow> onChanged;
  final VoidCallback onDelete;
  final RemapWarning? Function(String capturedKey)? warningBuilder;

  @override
  Widget build(BuildContext context) {
    // The trigger's modifiers live on the row (they become the section
    // header); the action's live inside its keyd text as `C-A-` prefixes.
    // Both sides are the same thing to a user, so both are chips.
    final action = KeyAction.parse(row.toKey);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChordField(
                    label: 'Press',
                    modifiers: row.modifiers,
                    keyName: row.fromKey,
                    catalog: catalog,
                    warningBuilder: warningBuilder,
                    onChanged: (modifiers, key) => onChanged(
                      row.copyWith(modifiers: modifiers, fromKey: key),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (action.isAdvanced)
                    _AdvancedAction(
                      row: row,
                      catalog: catalog,
                      onChanged: onChanged,
                    )
                  else
                    ChordField(
                      label: 'Send',
                      modifiers: action.modifiers,
                      keyName: action.key,
                      catalog: catalog,
                      // A key field on this side holds a keyd action: it must
                      // not be lower-cased or rejected for being absent from
                      // the key catalog, so that typing `macro(...)` or a
                      // prefixed action still works and switches this side to
                      // its raw editor.
                      validateAgainstCatalog: false,
                      footnote: _footnoteFor(row.toKey, action),
                      onChanged: (modifiers, key) => onChanged(
                        row.copyWith(toKey: KeyAction.compose(modifiers, key)),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete mapping',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  /// What the chord will be written as, shown only once it says something the
  /// chips do not: a bare key already reads the same in both vocabularies.
  static String? _footnoteFor(String toKey, KeyAction action) {
    if (action.key.isEmpty || action.modifiers.isEmpty) return null;
    return '${chordLabel(action.modifiers, action.key)}  ·  writes $toKey';
  }
}

/// The raw editor for an action the chips cannot express -- `macro(...)`,
/// `layer(...)`, an AltGr `G-` prefix.
///
/// Rendering those as chips would mean rewriting them, so they keep the
/// plain text box instead. Clearing the action switches back to chips.
class _AdvancedAction extends StatelessWidget {
  const _AdvancedAction({
    required this.row,
    required this.catalog,
    required this.onChanged,
  });

  final MappingRow row;
  final KeyCatalog catalog;
  final ValueChanged<MappingRow> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      KeyField(
        label: 'keyd action',
        value: row.toKey,
        catalog: catalog,
        validateAgainstCatalog: false,
        onChanged: (value) => onChanged(row.copyWith(toKey: value)),
      ),
      Row(
        children: [
          Expanded(
            child: Text(
              'This is a keyd expression, so it stays as typed.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () => onChanged(row.copyWith(toKey: '')),
            child: const Text('Use keys instead'),
          ),
        ],
      ),
    ],
  );
}
