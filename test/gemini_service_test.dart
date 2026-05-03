import 'package:flutter_test/flutter_test.dart';
import 'package:context_gif_ai/gemini_service/gemini_service.dart';

void main() {
  group('parseCaptionJson', () {
    test('parses a clean JSON response', () {
      const input = '{"category":"sarcasm","caption":"a long caption"}';
      final result = parseCaptionJson(input);
      expect(result.category, 'sarcasm');
      expect(result.caption, 'a long caption');
    });

    test('strips ```json fences', () {
      const input = '```json\n{"category":"chaos","caption":"unhinged"}\n```';
      final result = parseCaptionJson(input);
      expect(result.category, 'chaos');
      expect(result.caption, 'unhinged');
    });

    test('strips bare ``` fences', () {
      const input = '```\n{"category":"validation","caption":"yes"}\n```';
      final result = parseCaptionJson(input);
      expect(result.category, 'validation');
    });

    test('lowercases category', () {
      const input = '{"category":"SARCASM","caption":"x"}';
      expect(parseCaptionJson(input).category, 'sarcasm');
    });

    test('throws GeminiResponseException on missing caption', () {
      const input = '{"category":"sarcasm"}';
      expect(() => parseCaptionJson(input),
          throwsA(isA<GeminiResponseException>()));
    });

    test('throws GeminiResponseException on missing category', () {
      const input = '{"caption":"text"}';
      expect(() => parseCaptionJson(input),
          throwsA(isA<GeminiResponseException>()));
    });

    test('throws GeminiResponseException on invalid JSON', () {
      const input = 'not json at all';
      expect(() => parseCaptionJson(input),
          throwsA(isA<GeminiResponseException>()));
    });

    test('throws GeminiResponseException on empty caption', () {
      const input = '{"category":"sarcasm","caption":""}';
      expect(() => parseCaptionJson(input),
          throwsA(isA<GeminiResponseException>()));
    });

    test('throws GeminiResponseException on a JSON array root', () {
      const input = '[{"category":"sarcasm","caption":"x"}]';
      expect(() => parseCaptionJson(input),
          throwsA(isA<GeminiResponseException>()));
    });
  });

  group('exception type hierarchy', () {
    test('typed exceptions extend GeminiException', () {
      expect(GeminiAuthException('x'), isA<GeminiException>());
      expect(GeminiRateLimitException('x'), isA<GeminiException>());
      expect(GeminiNetworkException('x'), isA<GeminiException>());
      expect(GeminiResponseException('x'), isA<GeminiException>());
    });
  });
}
