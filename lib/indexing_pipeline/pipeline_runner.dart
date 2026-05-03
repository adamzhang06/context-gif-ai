import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../gemini_service/gemini_service.dart';
import '../library_scanner/library_scanner.dart';
import '../reaction_index/reaction_index.dart';
import 'backoff.dart';
import 'indexer.dart';
import 'indexing_progress.dart';

// mp4 deferred to follow-up issue (Gemini File API).
const _videoExtensions = {'.mp4'};

Stream<IndexingProgress> runPipeline({
  required GeminiService gemini,
  required ReactionIndex index,
  required List<String> folderPaths,
  bool Function()? isCancelled,
  Duration backoffInitialDelay = const Duration(seconds: 1),
  int backoffMaxAttempts = 5,
}) async* {
  final scanner = LibraryScanner();
  final allFiles = await scanner.scan(folderPaths);
  final imageFiles = allFiles
      .where((f) => !_videoExtensions.contains(p.extension(f).toLowerCase()))
      .toList();

  final indexer = Indexer(gemini: gemini, index: index);
  final total = imageFiles.length;
  var completed = 0;
  var skipped = 0;
  var failed = 0;

  for (final path in imageFiles) {
    if (isCancelled?.call() == true) {
      yield IndexingProgress(
        completed: completed,
        skipped: skipped,
        failed: failed,
        total: total,
        done: true,
      );
      return;
    }

    try {
      final existing = await index.findByPath(path);
      if (existing != null) {
        final currentHash = await _hashFile(File(path));
        if (currentHash == existing.fileHash) {
          skipped++;
          yield IndexingProgress(
            completed: completed,
            skipped: skipped,
            failed: failed,
            total: total,
            done: false,
            currentItem: path,
          );
          continue;
        }
      }

      await retryWithBackoff(
        () => indexer.indexFile(path),
        initialDelay: backoffInitialDelay,
        maxAttempts: backoffMaxAttempts,
      );
      completed++;
      yield IndexingProgress(
        completed: completed,
        skipped: skipped,
        failed: failed,
        total: total,
        done: false,
        currentItem: path,
      );
    } catch (e) {
      failed++;
      yield IndexingProgress(
        completed: completed,
        skipped: skipped,
        failed: failed,
        total: total,
        done: false,
        currentItem: path,
        error: '$path: $e',
      );
    }
  }

  yield IndexingProgress(
    completed: completed,
    skipped: skipped,
    failed: failed,
    total: total,
    done: true,
  );
}

Future<String> _hashFile(File file) async {
  final bytes = await file.readAsBytes();
  return sha256.convert(bytes).toString();
}
