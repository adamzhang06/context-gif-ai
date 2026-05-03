import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:context_gif_ai/api_key_store/api_key_store.dart';

void main() {
  late Map<String, String> _keychain;
  late ApiKeyStore store;

  ProcessRunner fakeRunner(Map<String, String> keychain) {
    return (executable, args, {String? stdinInput}) async {
      final sub = args.isNotEmpty ? args[0] : '';
      const account = 'gemini_api_key';
      const service = 'com.adamzhang.contextGifAi';

      // security -i: save passes key via stdin to avoid argv exposure.
      if (sub == '-i' && stdinInput != null) {
        final parts = stdinInput.trim().split(' ');
        final wIdx = parts.indexOf('-w');
        final value = wIdx != -1 && wIdx + 1 < parts.length ? parts[wIdx + 1] : '';
        keychain['$account@$service'] = value;
        return ProcessResult(0, 0, '', '');
      }

      if (sub == 'find-generic-password') {
        final value = keychain['$account@$service'];
        if (value == null) return ProcessResult(0, 44, '', 'not found');
        return ProcessResult(0, 0, value, '');
      }

      if (sub == 'delete-generic-password') {
        keychain.remove('$account@$service');
        return ProcessResult(0, 0, '', '');
      }

      return ProcessResult(0, 1, '', 'unknown command');
    };
  }

  setUp(() {
    _keychain = {};
    store = ApiKeyStore(runner: fakeRunner(_keychain));
  });

  test('save writes key to keychain', () async {
    await store.save('test-api-key');
    expect(_keychain['gemini_api_key@com.adamzhang.contextGifAi'], 'test-api-key');
  });

  test('retrieve returns stored key', () async {
    _keychain['gemini_api_key@com.adamzhang.contextGifAi'] = 'test-api-key';
    expect(await store.retrieve(), 'test-api-key');
  });

  test('retrieve returns null when key is missing', () async {
    expect(await store.retrieve(), isNull);
  });

  test('delete removes key from keychain', () async {
    _keychain['gemini_api_key@com.adamzhang.contextGifAi'] = 'test-api-key';
    await store.delete();
    expect(_keychain.containsKey('gemini_api_key@com.adamzhang.contextGifAi'), isFalse);
  });
}
