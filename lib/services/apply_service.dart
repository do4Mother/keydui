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

bool _helperExists(String path) {
  return File(path).existsSync();
}

Future<void> _cleanupTemp(String path) async {
  try {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
    final dir = file.parent;
    if (dir.existsSync()) {
      await dir.delete();
    }
  } catch (_) {
    // Ignore cleanup errors; they should not mask the real result.
  }
}

class PkexecApplyService implements ApplyService {
  PkexecApplyService({
    required this.runner,
    Future<String> Function(String contents)? writeTemp,
    bool Function(String path)? helperExists,
  })  : writeTemp = writeTemp ?? _writeTempFile,
        helperExists = helperExists ?? _helperExists;

  final ProcessRunner runner;
  final Future<String> Function(String contents) writeTemp;
  final bool Function(String path) helperExists;

  @override
  Future<ApplyResult> apply(String configText) async {
    final path = await writeTemp(configText);

    try {
      // Validate before asking for a password: no prompt for a config that
      // would not load anyway.
      final check = await runner.run('keyd', ['check', path]);
      if (!check.succeeded) {
        if (check.exitCode == 127) {
          return ApplyFailed(
              'keyd does not appear to be installed or is not in PATH');
        }
        final message = check.stderr.trim().isEmpty
            ? check.stdout.trim()
            : check.stderr.trim();
        return ApplyInvalid(message.isEmpty ? 'Invalid configuration' : message);
      }

      // Check if the helper exists before asking for a password.
      if (!helperExists(helperPath)) {
        return ApplyFailed(
            'The apply helper is not installed at $helperPath. Run: sudo ./install.sh');
      }

      final applied = await runner.run('pkexec', [helperPath, path]);
      return switch (applied.exitCode) {
        0 => const ApplySaved(),
        126 || 127 => const ApplyCancelled(),
        _ => ApplyFailed(applied.stderr.trim().isEmpty
            ? 'Could not apply the configuration (exit ${applied.exitCode})'
            : applied.stderr.trim()),
      };
    } finally {
      await _cleanupTemp(path);
    }
  }
}
