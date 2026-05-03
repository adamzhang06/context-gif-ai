import 'dart:io';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

class ApiKeyStore {
  ApiKeyStore({ProcessRunner? runner}) : _run = runner ?? Process.run;

  final ProcessRunner _run;
  static const _account = 'gemini_api_key';
  static const _service = 'com.adamzhang.contextGifAi';

  Future<void> save(String key) async {
    // Delete first so re-saves don't fail on duplicate items.
    await _run('security', [
      'delete-generic-password', '-a', _account, '-s', _service,
    ]);
    final result = await _run('security', [
      'add-generic-password', '-a', _account, '-s', _service, '-w', key,
    ]);
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
