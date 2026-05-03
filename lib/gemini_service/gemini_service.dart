import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:path/path.dart' as p;

const captionPrompt = '''
You are captioning reaction media for a chat recommender. Your caption will be embedded as a vector and matched against screenshots of real chat conversations — so describe what makes someone reach for this, not what it looks like.

Return your response as raw JSON (no markdown fences) with exactly two fields:

- "category": a single lowercase word for the dominant vibe (examples: "sarcasm", "celebration", "cringe", "validation", "deflection", "exhaustion", "agreement", "disbelief", "affection", "chaos")

- "caption": a multi-paragraph pragmatic caption covering all four of the following:

  1. The conversational move: what is the sender doing by sending this? (e.g. deflecting, roasting affectionately, expressing pained solidarity, signalling unhinged agreement)

  2. The trigger: what would the other person have just said or done to prompt this? Give 2–3 concrete example exchanges — write them as actual chat lines.

  3. The emotional register: be precise — not "funny" or "relatable" but "smug resignation", "chaotic vindication", "exhausted but correct energy".

  4. Misfire conditions: one situation where sending this would land wrong or feel off.

Skip describing the visual content unless it directly explains the meaning. Be ruthlessly specific — vague captions produce bad recommendations.
''';

class CaptionResult {
  CaptionResult({required this.caption, required this.category});
  final String caption;
  final String category;
}

CaptionResult parseCaptionJson(String raw) {
  var s = raw.trim();
  if (s.startsWith('```')) {
    s = s.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    s = s.replaceFirst(RegExp(r'\s*```\s*$'), '');
  }
  try {
    final decoded = jsonDecode(s);
    if (decoded is! Map<String, dynamic>) {
      throw GeminiResponseException('Expected JSON object, got ${decoded.runtimeType}');
    }
    final caption = (decoded['caption'] as String?)?.trim();
    final category = (decoded['category'] as String?)?.trim().toLowerCase();
    if (caption == null || caption.isEmpty || category == null || category.isEmpty) {
      throw GeminiResponseException('Missing or empty caption/category in JSON');
    }
    return CaptionResult(caption: caption, category: category);
  } on FormatException catch (e) {
    final preview = s.length > 200 ? '${s.substring(0, 200)}…' : s;
    throw GeminiResponseException(
      'Invalid JSON from Gemini: ${e.message}\nRaw: $preview',
    );
  }
}

sealed class GeminiException implements Exception {
  GeminiException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

class GeminiAuthException extends GeminiException {
  GeminiAuthException(super.message);
}

class GeminiRateLimitException extends GeminiException {
  GeminiRateLimitException(super.message);
}

class GeminiNetworkException extends GeminiException {
  GeminiNetworkException(super.message);
}

class GeminiResponseException extends GeminiException {
  GeminiResponseException(super.message);
}

class GeminiService {
  GeminiService(this._apiKey);

  final String _apiKey;

  static const _captionModelName = 'gemini-2.5-flash';
  static const _embeddingModelName = 'gemini-embedding-001';

  Future<CaptionResult> captionImage(File file) async {
    final bytes = await file.readAsBytes();
    final mimeType = _mimeForPath(file.path);
    return captionImageBytes(bytes, mimeType: mimeType);
  }

  Future<CaptionResult> captionImageBytes(
    Uint8List bytes, {
    required String mimeType,
  }) async {
    final model = GenerativeModel(
      model: _captionModelName,
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        maxOutputTokens: 8192,
      ),
    );
    final GenerateContentResponse response;
    try {
      response = await model.generateContent([
        Content.multi([
          TextPart(captionPrompt),
          DataPart(mimeType, bytes),
        ]),
      ]);
    } catch (e) {
      throw _mapException(e);
    }

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw GeminiResponseException('Empty response from Gemini');
    }
    return parseCaptionJson(text);
  }

  Future<Float32List> embed(String text) async {
    final model = GenerativeModel(
      model: _embeddingModelName,
      apiKey: _apiKey,
    );
    try {
      final response = await model.embedContent(Content.text(text));
      return Float32List.fromList(response.embedding.values);
    } catch (e) {
      throw _mapException(e);
    }
  }

  GeminiException _mapException(Object e) {
    if (e is InvalidApiKey) {
      return GeminiAuthException(e.message);
    }
    if (e is ServerException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('rate') || msg.contains('quota') || msg.contains('429')) {
        return GeminiRateLimitException(e.message);
      }
      return GeminiNetworkException(e.message);
    }
    if (e is GenerativeAIException) {
      return GeminiResponseException(e.message);
    }
    if (e is SocketException || e is HttpException) {
      return GeminiNetworkException(e.toString());
    }
    return GeminiResponseException(e.toString());
  }

  static String _mimeForPath(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        throw ArgumentError('Unsupported image extension: $ext');
    }
  }
}
