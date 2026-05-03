import 'dart:async';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../gemini_service/gemini_service.dart';
import '../reaction_index/reaction_index.dart';
import 'indexing_progress.dart';
import 'pipeline_runner.dart';

class _WorkerArgs {
  _WorkerArgs({
    required this.sendPort,
    required this.apiKey,
    required this.folderPaths,
    required this.dbPath,
  });
  final SendPort sendPort;
  final String apiKey;
  final List<String> folderPaths;
  final String dbPath;
}

class IndexingPipeline {
  Isolate? _isolate;
  ReceivePort? _receivePort;
  SendPort? _cancelSendPort;
  StreamController<IndexingProgress>? _controller;

  bool get isRunning => _isolate != null;

  Stream<IndexingProgress> start({
    required String apiKey,
    required List<String> folderPaths,
  }) {
    if (_isolate != null) {
      throw StateError('IndexingPipeline already running');
    }
    final controller = StreamController<IndexingProgress>();
    _controller = controller;
    _bootstrap(apiKey: apiKey, folderPaths: folderPaths);
    return controller.stream;
  }

  Future<void> _bootstrap({
    required String apiKey,
    required List<String> folderPaths,
  }) async {
    try {
      final dbPath = await _defaultDbPath();
      final receive = ReceivePort();
      _receivePort = receive;

      receive.listen((msg) {
        if (msg is SendPort) {
          _cancelSendPort = msg;
          return;
        }
        if (msg is Map) {
          final progress = IndexingProgress.fromMap(
            msg.cast<String, Object?>(),
          );
          _controller?.add(progress);
          if (progress.done) _cleanup();
        }
      });

      _isolate = await Isolate.spawn(
        _workerEntry,
        _WorkerArgs(
          sendPort: receive.sendPort,
          apiKey: apiKey,
          folderPaths: folderPaths,
          dbPath: dbPath,
        ),
      );
    } catch (e, st) {
      _controller?.addError(e, st);
      await _controller?.close();
      _controller = null;
    }
  }

  Future<void> stop() async {
    _cancelSendPort?.send('cancel');
  }

  void _cleanup() {
    _controller?.close();
    _controller = null;
    _isolate?.kill();
    _isolate = null;
    _receivePort?.close();
    _receivePort = null;
    _cancelSendPort = null;
  }

  static Future<String> _defaultDbPath() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return p.join(dir.path, 'reaction_index.db');
  }
}

Future<void> _workerEntry(_WorkerArgs args) async {
  final mainSend = args.sendPort;
  final cancelPort = ReceivePort();
  mainSend.send(cancelPort.sendPort);

  var cancelled = false;
  cancelPort.listen((msg) {
    if (msg == 'cancel') cancelled = true;
  });

  final index = await ReactionIndex.open(overridePath: args.dbPath);
  final gemini = GeminiService(args.apiKey);

  try {
    await for (final progress in runPipeline(
      gemini: gemini,
      index: index,
      folderPaths: args.folderPaths,
      isCancelled: () => cancelled,
    )) {
      mainSend.send(progress.toMap());
    }
  } finally {
    await index.close();
    cancelPort.close();
  }
}
