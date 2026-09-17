// test/services/process_runner_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/services/process_runner.dart';

void main() {
  test('runs a real command and captures stdout', () async {
    final outcome = await SystemProcessRunner().run('echo', ['hello']);
    expect(outcome.exitCode, 0);
    expect(outcome.stdout.trim(), 'hello');
  });

  test('reports a non-zero exit code', () async {
    final outcome = await SystemProcessRunner().run('false', const []);
    expect(outcome.exitCode, isNot(0));
  });

  test('a missing executable surfaces as exit code 127', () async {
    final outcome = await SystemProcessRunner().run(
      'keydui-no-such-binary',
      const [],
    );
    expect(outcome.exitCode, 127);
  });
}
