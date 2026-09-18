import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/main.dart';
import 'package:keydui/services/apply_service.dart';
import 'package:keydui/services/key_catalog.dart';
import 'package:keydui/state/mappings_controller.dart';

class StubApplyService implements ApplyService {
  @override
  Future<ApplyResult> apply(String configText) async => const ApplySaved();
}

void main() {
  testWidgets('app boots and shows loaded mappings', (tester) async {
    final controller = MappingsController(
      applyService: StubApplyService(),
      readConfig: () async => '[meta]\nleft = home\n',
    );
    await controller.load();
    await tester.pumpWidget(
      KeydUiApp(
        controller: controller,
        catalog: const KeyCatalog(['home', 'left']),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('keyd mappings'), findsOneWidget);
    expect(find.text('1 mapping'), findsOneWidget);
  });
}
