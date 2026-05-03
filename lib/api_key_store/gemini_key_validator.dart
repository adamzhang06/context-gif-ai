import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiKeyValidator {
  GeminiKeyValidator({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  // Lists models — lightweight call that only requires a valid key.
  Future<({bool valid, String? error})> validate(String key) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models',
      {'key': key},
    );
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      debugPrint('Gemini validate: status=${response.statusCode}');
      return (valid: response.statusCode == 200, error: null);
    } catch (e) {
      debugPrint('Gemini validate error: $e');
      return (valid: false, error: e.toString());
    }
  }
}
