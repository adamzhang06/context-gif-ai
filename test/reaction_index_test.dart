import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:context_gif_ai/reaction_index/reaction_index.dart';

void main() {
  late Directory tempDir;
  late ReactionIndex index;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('reaction_index_test_');
    index = await ReactionIndex.open(
      overridePath: p.join(tempDir.path, 'test.db'),
    );
  });

  tearDown(() async {
    await index.close();
    await tempDir.delete(recursive: true);
  });

  ReactionMediaRow buildRow({
    required String path,
    String caption = 'caption',
    String category = 'sarcasm',
    Float32List? embedding,
    String fileHash = 'h',
    int indexedAt = 0,
  }) =>
      ReactionMediaRow(
        path: path,
        caption: caption,
        category: category,
        embedding: embedding ?? Float32List.fromList([0.0]),
        fileHash: fileHash,
        indexedAt: indexedAt,
      );

  test('upsert and findByPath round-trips a row including category', () async {
    await index.upsert(buildRow(
      path: '/foo/bar.jpg',
      caption: 'a caption',
      category: 'celebration',
      embedding: Float32List.fromList([0.1, 0.2, 0.3, 0.4]),
      fileHash: 'abc123',
      indexedAt: 1000,
    ));

    final row = await index.findByPath('/foo/bar.jpg');
    expect(row, isNotNull);
    expect(row!.caption, 'a caption');
    expect(row.category, 'celebration');
    expect(row.fileHash, 'abc123');
    expect(row.indexedAt, 1000);
    expect(row.embedding[0], closeTo(0.1, 1e-6));
    expect(row.embedding[3], closeTo(0.4, 1e-6));
  });

  test('findByPath returns null when missing', () async {
    expect(await index.findByPath('/missing.jpg'), isNull);
  });

  test('upsert replaces existing row at same path', () async {
    await index.upsert(buildRow(path: '/a.jpg', caption: 'first'));
    await index.upsert(buildRow(path: '/a.jpg', caption: 'second'));
    expect((await index.findByPath('/a.jpg'))!.caption, 'second');
    expect(await index.count(), 1);
  });

  test('findByCategory returns all rows in that category', () async {
    await index.upsert(buildRow(path: '/a.jpg', category: 'sarcasm'));
    await index.upsert(buildRow(path: '/b.jpg', category: 'sarcasm'));
    await index.upsert(buildRow(path: '/c.jpg', category: 'celebration'));

    final sarcastic = await index.findByCategory('sarcasm');
    expect(sarcastic.length, 2);
    expect(sarcastic.map((r) => r.path).toSet(), {'/a.jpg', '/b.jpg'});

    final celebratory = await index.findByCategory('celebration');
    expect(celebratory.length, 1);
  });

  test('findByCategory is case-insensitive on lookup', () async {
    await index.upsert(buildRow(path: '/a.jpg', category: 'sarcasm'));
    expect((await index.findByCategory('SARCASM')).length, 1);
  });

  test('searchSimilar returns rows ranked by cosine similarity', () async {
    await index.upsert(buildRow(
      path: '/aligned.jpg',
      embedding: Float32List.fromList([1.0, 0.0, 0.0]),
    ));
    await index.upsert(buildRow(
      path: '/orthogonal.jpg',
      embedding: Float32List.fromList([0.0, 1.0, 0.0]),
    ));
    await index.upsert(buildRow(
      path: '/opposite.jpg',
      embedding: Float32List.fromList([-1.0, 0.0, 0.0]),
    ));

    final results = await index.searchSimilar(
      Float32List.fromList([1.0, 0.0, 0.0]),
      topK: 3,
    );

    expect(results.length, 3);
    expect(results[0].row.path, '/aligned.jpg');
    expect(results[0].score, closeTo(1.0, 1e-6));
    expect(results[1].row.path, '/orthogonal.jpg');
    expect(results[1].score, closeTo(0.0, 1e-6));
    expect(results[2].row.path, '/opposite.jpg');
    expect(results[2].score, closeTo(-1.0, 1e-6));
  });

  test('searchSimilar respects topK', () async {
    for (var i = 0; i < 5; i++) {
      await index.upsert(buildRow(
        path: '/file$i.jpg',
        embedding: Float32List.fromList([i.toDouble(), 0.0]),
      ));
    }
    final results = await index.searchSimilar(
      Float32List.fromList([1.0, 0.0]),
      topK: 2,
    );
    expect(results.length, 2);
  });
}
