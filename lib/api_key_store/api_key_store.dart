import 'dart:convert';
import 'dart:io';

// macOS-only dev implementation — see docs/adr/0004 before adding platforms.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? stdinInput,
});

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments, {
  String? stdinInput,
}) async {
  if (stdinInput == null) {
    return Process.run(executable, arguments);
  }
  final process = await Process.start(executable, arguments);
  process.stdin.write(stdinInput);
  await process.stdin.close();
  final out = StringBuffer();
  final err = StringBuffer();
  await Future.wait([
    process.stdout.transform(utf8.decoder).forEach(out.write),
    process.stderr.transform(utf8.decoder).forEach(err.write),
  ]);
  return ProcessResult(process.pid, await process.exitCode, out.toString(), err.toString());
}

class ApiKeyStore {
  ApiKeyStore({ProcessRunner? runner}) : _run = runner ?? _runProcess;

  final ProcessRunner _run;
  static const _account = 'gemini_api_key';
  static const _service = 'com.adamzhang.contextGifAi';

  Future<void> save(String key) async {
    // Delete first so re-saves don't fail on duplicate items.
    await _run('security', [
      'delete-generic-password', '-a', _account, '-s', _service,
    ]);
    // Key passed via stdin to security -i to avoid argv exposure in ps.
    final result = await _run(
      'security', ['-i'],
      stdinInput: 'add-generic-password -a $_account -s $_service -w $key\n',
    );
    if (result.exitCode != 0) {
      throw Exception('Keychain write failed: ${result.stderr}');
    }
  }

  Future<String?> retrieve() async {
    final result = await _run('security', [
      'find-generic-password', '-a', _account, '-s', _service, '-w',
    ]);
    if (result.exitCode != 0) return null;
    final value = (result.stdout as String).trim();
    return value.isEmpty ? null : value;
  }

  Future<void> delete() async {
    await _run('security', [
      'delete-generic-password', '-a', _account, '-s', _service,
    ]);
  }
}
