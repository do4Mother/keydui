import 'dart:io';

import 'package:flutter/material.dart';

import 'services/apply_service.dart';
import 'services/key_catalog.dart';
import 'services/process_runner.dart';
import 'state/mappings_controller.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const runner = SystemProcessRunner();
  final catalog = await KeyCatalog.load(runner);
  final controller = MappingsController(
    applyService: PkexecApplyService(runner: runner),
    readConfig: () async {
      final file = File(configPath);
      return file.existsSync() ? file.readAsString() : '';
    },
  );
  await controller.load();

  runApp(KeydUiApp(controller: controller, catalog: catalog));
}

class KeydUiApp extends StatelessWidget {
  const KeydUiApp({super.key, required this.controller, required this.catalog});

  final MappingsController controller;
  final KeyCatalog catalog;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'keyd UI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomePage(controller: controller, catalog: catalog),
    );
  }
}
