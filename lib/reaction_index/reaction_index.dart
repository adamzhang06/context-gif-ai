import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class ReactionMediaRow {
  ReactionMediaRow({
    required this.path,
    required this.caption,
    required this.category,
    required this.embedding,
    required this.fileHash,
    required this.indexedAt,
  });

  final String path;
  final String caption;
  final String category;
  final Float32List embedding;
  final String fileHash;
  final int indexedAt;
}

class ScoredRow {
  ScoredRow(this.row, this.score);
  final ReactionMediaRow row;
  final double score;
}

class ReactionIndex {
  ReactionIndex._(this._db);

  final Database _db;
  static bool _ffiInitialized = false;

  static Future<ReactionIndex> open({String? overridePath}) async {
    if (!_ffiInitialized) {
      sqfliteFfiInit();
      _ffiInitialized = true;
    }
    final dbPath = overridePath ?? await _defaultPath();
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE reaction_media (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              path TEXT NOT NULL UNIQUE,
              caption TEXT,
              category TEXT,
              embedding BLOB,
              indexed_at INTEGER,
              file_hash TEXT
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_reaction_media_category ON reaction_media(category)',
          );
        },
      ),
    );
    return ReactionIndex._(db);
  }

  static Future<String> _defaultPath() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return p.join(dir.path, 'reaction_index.db');
  }

  Future<void> upsert(ReactionMediaRow row) async {
    await _db.insert(
      'reaction_media',
      {
        'path': row.path,
        'caption': row.caption,
        'category': row.category,
        'embedding': row.embedding.buffer.asUint8List(
          row.embedding.offsetInBytes,
          row.embedding.lengthInBytes,
        ),
        'indexed_at': row.indexedAt,
        'file_hash': row.fileHash,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReactionMediaRow?> findByPath(String path) async {
    final rows = await _db.query(
      'reaction_media',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowFromMap(rows.first);
  }

  Future<List<ReactionMediaRow>> findByCategory(String category) async {
    final rows = await _db.query(
      'reaction_media',
      where: 'category = ?',
      whereArgs: [category.toLowerCase()],
    );
    return rows.map(_rowFromMap).toList();
  }

  Future<List<ScoredRow>> searchSimilar(
    Float32List query, {
    int topK = 10,
  }) async {
    final rows = await _db.query('reaction_media');
    final scored = <ScoredRow>[];
    for (final r in rows) {
      final row = _rowFromMap(r);
      final score = _cosineSimilarity(query, row.embedding);
      scored.add(ScoredRow(row, score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(topK).toList();
  }

  Future<int> count() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS c FROM reaction_media');
    return result.first['c'] as int;
  }

  Future<void> close() => _db.close();

  ReactionMediaRow _rowFromMap(Map<String, Object?> row) {
    final blob = row['embedding'] as Uint8List;
    final embedding = Float32List.view(
      blob.buffer,
      blob.offsetInBytes,
      blob.lengthInBytes ~/ 4,
    );
    return ReactionMediaRow(
      path: row['path'] as String,
      caption: row['caption'] as String,
      category: row['category'] as String,
      embedding: embedding,
      fileHash: row['file_hash'] as String,
      indexedAt: row['indexed_at'] as int,
    );
  }

  static double _cosineSimilarity(Float32List a, Float32List b) {
    if (a.length != b.length) {
      throw ArgumentError(
        'Embedding length mismatch: ${a.length} vs ${b.length}',
      );
    }
    var dot = 0.0;
    var na = 0.0;
    var nb = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      na += a[i] * a[i];
      nb += b[i] * b[i];
    }
    final denom = math.sqrt(na) * math.sqrt(nb);
    if (denom == 0) return 0;
    return dot / denom;
  }
}
