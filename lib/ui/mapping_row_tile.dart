import 'package:flutter/material.dart';

import '../models/mapping_row.dart';
import '../models/modifier.dart';
import '../services/key_catalog.dart';
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
  final String? Function(String capturedKey)? warningBuilder;

  @override
  Widget build(BuildContext context) {
    // A from-field listen capture fires `onModifiersCaptured` and then
    // `onChanged` synchronously, before this widget rebuilds. Both closures
    // close over the SAME `row` (this build's field, not a live reference),
    // so if each independently called the outer `onChanged` with
    // `row.copyWith(...)`, the second call would derive from the stale,
    // pre-capture `row` and silently drop the modifier update the first
    // call made. Stashing the captured modifiers in a build-local variable
    // and folding them into the single `onChanged` call the key capture
    // triggers keeps both pieces of a Meta+Left-style capture together.
    Set<Modifier>? capturedModifiers;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (final modifier in Modifier.values)
                  FilterChip(
                    label: Text(modifier.keydName),
                    selected: row.modifiers.contains(modifier),
                    onSelected: (selected) {
                      final next = row.modifiers.toSet();
                      selected ? next.add(modifier) : next.remove(modifier);
                      onChanged(row.copyWith(modifiers: next));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: KeyField(
                    label: 'From',
                    value: row.fromKey,
                    catalog: catalog,
                    warningBuilder: warningBuilder,
                    onModifiersCaptured: (mods) => capturedModifiers = mods,
                    onChanged: (key) => onChanged(row.copyWith(
                      modifiers: capturedModifiers,
                      fromKey: key,
                    )),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward),
                ),
                Expanded(
                  child: KeyField(
                    label: 'To',
                    value: row.toKey,
                    catalog: catalog,
                    // A to-field holds a keyd action, not a bare key name
                    // (e.g. `S-home`, `macro(...)`) -- it must not be
                    // validated against the key catalog or lower-cased.
                    validateAgainstCatalog: false,
                    onChanged: (key) => onChanged(row.copyWith(toKey: key)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete mapping',
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
