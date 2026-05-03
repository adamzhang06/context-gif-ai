import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:context_gif_ai/gemini_service/gemini_service.dart';
import 'package:context_gif_ai/indexing_pipeline/indexing_progress.dart';
import 'package:context_gif_ai/indexing_pipeline/pipeline_runner.dart';
import 'package:context_gif_ai/reaction_index/reaction_index.dart';

class _FakeGemini extends GeminiService {
  _FakeGemini() : super('fake');

  int captionCalls = 0;
  int rateLimitsToThrowEachCall = 0;
  int _consecutiveRateLimits = 0;

  @override
  Future<CaptionResult> captionImage(File file) async {
    captionCalls++;
    if (_consecutiveRateLimits < rateLimitsToThrowEachCall) {
      _consecutiveRateLimits++;
      throw GeminiRateLimitException('rate limit');
    }
    _consecutiveRateLimits = 0;
    return CaptionResult(caption: 'cap-$captionCalls', category: 'sarcasm');
  }

  @override
  Future<Float32List> embed(String text) async =>
      Float32List.fromList([0.1, 0.2, 0.3]);
}

void main() {
  late Directory tempDir;
  late ReactionIndex index;
  late _FakeGemini gemini;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pipeline_test_');
    index = await ReactionIndex.open(
      overridePath: p.join(tempDir.path, 'test.db'),
    );
    gemini = _FakeGemini();
  });

  tearDown(() async {
    await index.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> writeJpg(String name) async {
    final f = File(p.join(tempDir.path, name));
    await f.writeAsBytes([0xFF, 0xD8, 0xFF, name.hashCode & 0xFF, 0x00]);
  }

  Stream<IndexingProgress> run({
    bool Function()? isCancelled,
    int rateLimits = 0,
  }) {
    gemini.rateLimitsToThrowEachCall = rateLimits;
    return runPipeline(
      gemini: gemini,
      index: index,
      folderPaths: [tempDir.path],
      isCancelled: isCancelled,
      backoffInitialDelay: Duration.zero,
    );
  }

  test('processes all images and emits done at end', () async {
    await writeJpg('a.jpg');
    await writeJpg('b.jpg');
    await writeJpg('c.jpg');

    final events = await run().toList();

    final last = events.last;
    expect(last.done, true);
    expect(last.completed, 3);
    expect(last.failed, 0);
    expect(last.skipped, 0);
    expect(last.total, 3);
    expect(await index.count(), 3);
  });

  test('skips already-indexed files with matching hash', () async {
    await writeJpg('a.jpg');

    await run().toList();
    expect(gemini.captionCalls, 1);

    final events = await run().toList();
    expect(gemini.captionCalls, 1, reason: 'should skip without re-captioning');
    expect(events.last.skipped, 1);
    expect(events.last.completed, 0);
  });

  test('re-indexes when file content changes (hash differs)', () async {
    final f = File(p.join(tempDir.path, 'a.jpg'));
    await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0x01]);
    await run().toList();
    expect(gemini.captionCalls, 1);

    await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0x02, 0x03]);
    await run().toList();
    expect(gemini.captionCalls, 2);
  });

  test('mp4 files are excluded from total', () async {
    await writeJpg('a.jpg');
    await File(p.join(tempDir.path, 'b.mp4')).writeAsBytes([0]);

    final events = await run().toList();
    expect(events.last.total, 1);
    expect(events.last.completed, 1);
  });

  test('failed item does not crash; pipeline completes', () async {
    await writeJpg('a.jpg');
    await writeJpg('b.jpg');

    // 999 rate-limits per call exhausts backoff.
    final events = await run(rateLimits: 999).toList();

    expect(events.last.done, true);
    expect(events.last.failed, 2);
    expect(events.last.completed, 0);
  });

  test('rate limit triggers backoff then succeeds', () async {
    await writeJpg('a.jpg');

    final events = await run(rateLimits: 2).toList();

    expect(events.last.completed, 1);
    expect(events.last.failed, 0);
    expect(gemini.captionCalls, 3);
  });

  test('cancellation stops the loop early with done=true', () async {
    for (var i = 0; i < 10; i++) {
      await writeJpg('f$i.jpg');
    }

    var cancelled = false;
    final events = <IndexingProgress>[];
    await for (final e in run(isCancelled: () => cancelled)) {
      events.add(e);
      if (events.length == 3) cancelled = true;
    }

    expect(events.last.done, true);
    expect(events.last.completed, lessThan(10));
  });

  test('progress events report current item', () async {
    await writeJpg('a.jpg');
    final events = await run().toList();
    final progressEvents = events.where((e) => !e.done).toList();
    expect(progressEvents, isNotEmpty);
    expect(progressEvents.first.currentItem, isNotNull);
  });
}
