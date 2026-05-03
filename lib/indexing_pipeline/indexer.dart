import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../gemini_service/gemini_service.dart';
import '../reaction_index/reaction_index.dart';

class Indexer {
  Indexer({required this.gemini, required this.index});

  final GeminiService gemini;
  final ReactionIndex index;

  static const _videoExtensions = {'.mp4'};

  Future<ReactionMediaRow> indexFile(String path) async {
    final ext = p.extension(path).toLowerCase();
    if (_videoExtensions.contains(ext)) {
      throw UnsupportedError(
        'Video indexing not implemented yet (deferred to issue #6): $path',
      );
    }

    final file = File(path);
    final caption = await gemini.captionImage(file);
    final embedding = await gemini.embed(caption.caption);
    final hash = await _hashFile(file);

    final row = ReactionMediaRow(
      path: path,
      caption: caption.caption,
      category: caption.category,
      embedding: embedding,
      fileHash: hash,
      indexedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await index.upsert(row);
    return row;
  }

  Future<String> _hashFile(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
