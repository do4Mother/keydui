import 'package:flutter/material.dart';

import '../services/apply_service.dart';
import '../services/key_catalog.dart';
import '../state/mappings_controller.dart';
import 'mapping_row_tile.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller, required this.catalog});

  final MappingsController controller;
  final KeyCatalog catalog;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  Future<void> _save() async {
    final result = await widget.controller.save();
    if (!mounted) return;
    final message = switch (result) {
      ApplySaved() => 'Mappings applied',
      ApplyInvalid(:final message) => 'keyd rejected the config: $message',
      ApplyCancelled() => 'Cancelled — nothing was changed',
      ApplyFailed(:final message) => 'Could not apply: $message',
    };
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final rows = controller.rows;

    return Scaffold(
      appBar: AppBar(
        title: const Text('keyd mappings'),
        actions: [
          Center(
            child: Text(
              rows.length == 1 ? '1 mapping' : '${rows.length} mappings',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save and apply',
            onPressed: controller.canSave ? _save : null,
          ),
        ],
      ),
      body: Column(
        children: [
          if (controller.loadError != null)
            _Notice('Could not read $configPath: ${controller.loadError}'),
          if (widget.catalog.isFallback)
            const _Notice(
              'keyd was not found, so the key list is a built-in fallback. '
              'Saving will not work until keyd is installed.',
            ),
          Expanded(
            child: rows.isEmpty
                ? const Center(
                    child: Text('No mappings yet — press + to add one'),
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) => MappingRowTile(
                      key: ValueKey(index),
                      row: rows[index],
                      catalog: widget.catalog,
                      warningBuilder: (key) =>
                          controller.remapWarningFor(key, excludingIndex: index),
                      onChanged: (row) => controller.updateRow(index, row),
                      onDelete: () => controller.removeRow(index),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.addRow,
        tooltip: 'Add mapping',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Text(message, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}
