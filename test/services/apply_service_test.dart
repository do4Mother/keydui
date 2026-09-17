import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:keydui/services/apply_service.dart';
import 'package:keydui/services/process_runner.dart';

import '../support/fake_process_runner.dart';

PkexecApplyService serviceWith(
  FakeProcessRunner runner, {
  Future<String> Function(String contents)? writeTemp,
  bool Function(String path)? helperExists,
}) => PkexecApplyService(
  runner: runner,
  writeTemp: writeTemp ?? (contents) async => '/tmp/fake.conf',
  helperExists: helperExists ?? ((_) => true),
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
    expect(runner.calls.last, [
      'pkexec',
      '/usr/lib/keydui/keydui-apply',
      '/tmp/fake.conf',
    ]);
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

  test('temp directory is removed after successful apply', () async {
    final tempDir = await Directory.systemTemp.createTemp('keydui_test_');
    final configFile = File('${tempDir.path}/default.conf');
    await configFile.writeAsString('test');
    final configPath = configFile.path;

    final runner = FakeProcessRunner({
      'keyd': const ProcessOutcome(exitCode: 0),
      'pkexec': const ProcessOutcome(exitCode: 0),
    });

    final result = await serviceWith(
      runner,
      writeTemp: (contents) async => configPath,
    ).apply('[main]\ncapslock = esc\n');

    expect(result, isA<ApplySaved>());
    expect(configFile.existsSync(), false);
    expect(tempDir.existsSync(), false);
  });

  test('temp directory is removed after failed apply', () async {
    final tempDir = await Directory.systemTemp.createTemp('keydui_test_');
    final configFile = File('${tempDir.path}/default.conf');
    await configFile.writeAsString('test');
    final configPath = configFile.path;

    final runner = FakeProcessRunner({
      'keyd': const ProcessOutcome(exitCode: 0),
      'pkexec': const ProcessOutcome(exitCode: 2, stderr: 'reload failed'),
    });

    final result = await serviceWith(
      runner,
      writeTemp: (contents) async => configPath,
    ).apply('[main]\ncapslock = esc\n');

    expect(result, isA<ApplyFailed>());
    expect(configFile.existsSync(), false);
    expect(tempDir.existsSync(), false);
  });

  test('keyd missing (exit 127) reports failed with keyd message', () async {
    final runner = FakeProcessRunner({
      'keyd': const ProcessOutcome(
        exitCode: 127,
        stderr: 'ProcessException: No such file or directory',
      ),
    });
    final result = await serviceWith(runner).apply('x');
    expect(result, isA<ApplyFailed>());
    expect(
      (result as ApplyFailed).message,
      contains('keyd does not appear to be installed'),
    );
    expect(runner.calls.map((c) => c.first), isNot(contains('pkexec')));
  });

  test('missing helper produces failed with install message', () async {
    final runner = FakeProcessRunner({
      'keyd': const ProcessOutcome(exitCode: 0),
    });
    final result = await serviceWith(
      runner,
      helperExists: (_) => false,
    ).apply('x');
    expect(result, isA<ApplyFailed>());
    expect((result as ApplyFailed).message, contains('install.sh'));
    expect(runner.calls.map((c) => c.first), isNot(contains('pkexec')));
  });
}
