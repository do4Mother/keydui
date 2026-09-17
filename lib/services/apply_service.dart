import 'dart:io';

import 'process_runner.dart';

const helperPath = '/usr/lib/keydui/keydui-apply';
const configPath = '/etc/keyd/default.conf';

sealed class ApplyResult {
  const ApplyResult();
}

class ApplySaved extends ApplyResult {
  const ApplySaved();
}

class ApplyInvalid extends ApplyResult {
  const ApplyInvalid(this.message);
  final String message;
}

class ApplyCancelled extends ApplyResult {
  const ApplyCancelled();
}

class ApplyFailed extends ApplyResult {
  const ApplyFailed(this.message);
  final String message;
}

abstract class ApplyService {
  Future<ApplyResult> apply(String configText);
}

Future<String> _writeTempFile(String contents) async {
  final dir = await Directory.systemTemp.createTemp('keydui');
  final file = File('${dir.path}/default.conf');
  await file.writeAsString(contents);
  return file.path;
}

class PkexecApplyService implements ApplyService {
  PkexecApplyService({
    required this.runner,
    Future<String> Function(String contents)? writeTemp,
  }) : writeTemp = writeTemp ?? _writeTempFile;

  final ProcessRunner runner;
  final Future<String> Function(String contents) writeTemp;

  @override
  Future<ApplyResult> apply(String configText) async {
    final path = await writeTemp(configText);

    // Validate before asking for a password: no prompt for a config that
    // would not load anyway.
    final check = await runner.run('keyd', ['check', path]);
    if (!check.succeeded) {
      final message = check.stderr.trim().isEmpty
          ? check.stdout.trim()
          : check.stderr.trim();
      return ApplyInvalid(message.isEmpty ? 'Invalid configuration' : message);
    }

    final applied = await runner.run('pkexec', [helperPath, path]);
    return switch (applied.exitCode) {
      0 => const ApplySaved(),
      126 || 127 => const ApplyCancelled(),
      _ => ApplyFailed(applied.stderr.trim().isEmpty
          ? 'Could not apply the configuration (exit ${applied.exitCode})'
          : applied.stderr.trim()),
    };
  }
}
