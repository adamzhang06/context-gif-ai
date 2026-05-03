import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:context_gif_ai/library_scanner/library_scanner.dart';

void main() {
  late Directory tempDir;
  late LibraryScanner scanner;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('library_scanner_test_');
    scanner = LibraryScanner();
  });

  tearDown(() => tempDir.delete(recursive: true));

  Future<void> createFile(String relativePath) async {
    final file = File(p.join(tempDir.path, relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsBytes([]);
  }

  test('discovers all supported file types', () async {
    for (final ext in ['.gif', '.jpg', '.jpeg', '.png', '.webp', '.mp4']) {
      await createFile('file$ext');
    }
    final results = await scanner.scan([tempDir.path]);
    expect(results.length, 6);
  });

  test('ignores unsupported file types', () async {
    await createFile('document.pdf');
    await createFile('video.mov');
    await createFile('archive.zip');
    await createFile('text.txt');
    final results = await scanner.scan([tempDir.path]);
    expect(results, isEmpty);
  });

  test('scans recursively into subdirectories', () async {
    await createFile('a/b/c/image.jpg');
    final results = await scanner.scan([tempDir.path]);
    expect(results.length, 1);
  });

  test('combines results across multiple folders', () async {
    final dir2 =
        await Directory.systemTemp.createTemp('library_scanner_test2_');
    addTearDown(() => dir2.delete(recursive: true));

    await createFile('reaction.gif');
    await File(p.join(dir2.path, 'clip.mp4')).writeAsBytes([]);

    final results = await scanner.scan([tempDir.path, dir2.path]);
    expect(results.length, 2);
  });

  test('skips non-existent folders without throwing', () async {
    final results = await scanner.scan(['/nonexistent/path/that/does/not/exist']);
    expect(results, isEmpty);
  });

  test('count matches real reaction library', () async {
    const libraryPath =
        'data/reaction-library';
    if (!await Directory(libraryPath).exists()) return;
    final results = await scanner.scan([libraryPath]);
    expect(results.length, 396);
  });
}
