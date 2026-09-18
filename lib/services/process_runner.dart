import 'dart:io';

class ProcessOutcome {
  const ProcessOutcome({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;

  bool get succeeded => exitCode == 0;
}

abstract class ProcessRunner {
  Future<ProcessOutcome> run(String executable, List<String> arguments);
}

class SystemProcessRunner implements ProcessRunner {
  const SystemProcessRunner();

  @override
  Future<ProcessOutcome> run(String executable, List<String> arguments) async {
    try {
      final result = await Process.run(executable, arguments);
      return ProcessOutcome(
        exitCode: result.exitCode,
        stdout: result.stdout as String? ?? '',
        stderr: result.stderr as String? ?? '',
      );
    } on ProcessException catch (e) {
      // Matches the shell convention for "command not found".
      return ProcessOutcome(exitCode: 127, stderr: e.message);
    }
  }
}
