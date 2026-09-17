import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/services/apply_service.dart';
import 'package:keydui/services/process_runner.dart';
import '../support/fake_process_runner.dart';

PkexecApplyService serviceWith(FakeProcessRunner runner) => PkexecApplyService(
      runner: runner,
      writeTemp: (contents) async => '/tmp/fake.conf',
    );

void main() {
  test('invalid config never reaches pkexec', () async {
    final runner = FakeProcessRunner({
      'keyd': const ProcessOutcome(exitCode: 1, stderr: 'line 3: bad key'),
    });
    final result = await serviceWith(runner).apply('[main]\nbogus = x\n');
    expect(result, isA<ApplyInvalid>());
    expect((result as ApplyInvalid).message, contains('line 3'));
    expect(runner.calls.map((c) => c.first), isNot(contains('pkexec')));
  });

  test('valid config is handed to pkexec and succeeds', () async {
    final runner = FakeProcessRunner({
      'keyd': const ProcessOutcome(exitCode: 0),
      'pkexec': const ProcessOutcome(exitCode: 0),
    });
    final result = await serviceWith(runner).apply('[main]\ncapslock = esc\n');
    expect(result, isA<ApplySaved>());
    expect(runner.calls.last,
        ['pkexec', '/usr/lib/keydui/keydui-apply', '/tmp/fake.conf']);
  });

  test('dismissed password dialog reports cancelled', () async {
    for (final code in [126, 127]) {
      final runner = FakeProcessRunner({
        'keyd': const ProcessOutcome(exitCode: 0),
        'pkexec': ProcessOutcome(exitCode: code),
      });
      expect(await serviceWith(runner).apply('x'), isA<ApplyCancelled>());
    }
  });

  test('reload failure reports failed with stderr', () async {
    final runner = FakeProcessRunner({
      'keyd': const ProcessOutcome(exitCode: 0),
      'pkexec': const ProcessOutcome(exitCode: 2, stderr: 'reload failed'),
    });
    final result = await serviceWith(runner).apply('x');
    expect(result, isA<ApplyFailed>());
    expect((result as ApplyFailed).message, contains('reload failed'));
  });
}
