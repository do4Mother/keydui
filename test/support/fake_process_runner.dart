import 'package:keydui/services/process_runner.dart';

class FakeProcessRunner implements ProcessRunner {
  FakeProcessRunner(this.responses);

  /// Keyed by executable name.
  final Map<String, ProcessOutcome> responses;
  final List<List<String>> calls = [];

  @override
  Future<ProcessOutcome> run(String executable, List<String> arguments) async {
    calls.add([executable, ...arguments]);
    return responses[executable] ??
        const ProcessOutcome(exitCode: 127, stderr: 'not stubbed');
  }
}
