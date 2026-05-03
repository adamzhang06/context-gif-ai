import 'dart:io';
import 'package:path/path.dart' as p;

class LibraryScanner {
  static const supportedExtensions = {
    '.gif', '.jpg', '.jpeg', '.png', '.webp', '.mp4',
  };

  Future<List<String>> scan(List<String> folderPaths) async {
    final results = <String>[];
    for (final folderPath in folderPaths) {
      final dir = Directory(folderPath);
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(ext)) {
            results.add(entity.path);
          }
        }
      }
    }
    return results;
  }
}
