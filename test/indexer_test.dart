import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:context_gif_ai/gemini_service/gemini_service.dart';
import 'package:context_gif_ai/indexing_pipeline/indexer.dart';
import 'package:context_gif_ai/reaction_index/reaction_index.dart';

class _FakeGeminiService extends GeminiService {
  _FakeGeminiService({
    required this.captionToReturn,
    required this.embeddingToReturn,
  }) : super('fake-key');

  CaptionResult captionToReturn;
  Float32List embeddingToReturn;

  File? lastCaptionedFile;
  String? lastEmbeddedText;

  @override
  Future<CaptionResult> captionImage(File file) async {
    lastCaptionedFile = file;
    return captionToReturn;
  }

  @override
  Future<Float32List> embed(String text) async {
    lastEmbeddedText = text;
    return embeddingToReturn;
  }
}

void main() {
  late Directory tempDir;
  late ReactionIndex index;
  late _FakeGeminiService gemini;
  late Indexer indexer;
  late File testImage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('indexer_test_');
    index = await ReactionIndex.open(
      overridePath: p.join(tempDir.path, 'test.db'),
    );
    gemini = _FakeGeminiService(
      captionToReturn: CaptionResult(
        caption: 'pragmatic caption text',
        category: 'sarcasm',
      ),
      embeddingToReturn: Float32List.fromList([0.5, 0.6, 0.7]),
    );
    indexer = Indexer(gemini: gemini, index: index);

    testImage = File(p.join(tempDir.path, 'test.jpg'));
    await testImage.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]);
  });

  tearDown(() async {
    await index.close();
    await tempDir.delete(recursive: true);
  });

  test('indexFile captions, embeds, hashes, and upserts', () async {
    final row = await indexer.indexFile(testImage.path);

    expect(gemini.lastCaptionedFile?.path, testImage.path);
    expect(gemini.lastEmbeddedText, 'pragmatic caption text');
    expect(row.caption, 'pragmatic caption text');
    expect(row.category, 'sarcasm');
    expect(row.embedding[0], closeTo(0.5, 1e-6));
    expect(row.fileHash, isNotEmpty);
    expect(row.indexedAt, greaterThan(0));
  });

  test('indexed row is persisted and retrievable', () async {
    await indexer.indexFile(testImage.path);
    final stored = await index.findByPath(testImage.path);
    expect(stored, isNotNull);
    expect(stored!.caption, 'pragmatic caption text');
    expect(stored.category, 'sarcasm');
    expect(stored.embedding.length, 3);
  });

  test('re-indexing same file replaces the row', () async {
    await indexer.indexFile(testImage.path);

    gemini.captionToReturn = CaptionResult(
      caption: 'updated caption',
      category: 'celebration',
    );
    gemini.embeddingToReturn = Float32List.fromList([9.0, 9.0, 9.0]);
    await indexer.indexFile(testImage.path);

    final stored = await index.findByPath(testImage.path);
    expect(stored!.caption, 'updated caption');
    expect(stored.category, 'celebration');
    expect(stored.embedding[0], closeTo(9.0, 1e-6));
    expect(await index.count(), 1);
  });

  test('mp4 throws UnsupportedError (deferred to #6)', () async {
    final mp4 = File(p.join(tempDir.path, 'clip.mp4'));
    await mp4.writeAsBytes([0]);
    expect(() => indexer.indexFile(mp4.path),
        throwsA(isA<UnsupportedError>()));
  });
}
