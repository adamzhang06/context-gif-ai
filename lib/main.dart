import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_key_store/api_key_screen.dart';
import 'api_key_store/api_key_store.dart';
import 'api_key_store/gemini_key_validator.dart';
import 'indexing_pipeline/indexing_pipeline.dart';
import 'indexing_pipeline/indexing_progress.dart';
import 'library_scanner/folder_selection_screen.dart';
import 'reaction_index/reaction_index.dart';

void main() {
  runApp(const ContextGifApp());
}

class ContextGifApp extends StatelessWidget {
  const ContextGifApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Context GIF AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  final _store = ApiKeyStore();
  late final _validator = GeminiKeyValidator();

  bool _checked = false;
  bool _hasKey = false;
  String? _apiKey;
  List<String> _folders = [];

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    final key = await _store.retrieve();
    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList('reaction_library_folders') ?? [];
    setState(() {
      _apiKey = key;
      _hasKey = key != null;
      _folders = folders;
      _checked = true;
    });
  }

  Future<void> _onFoldersSelected(List<String> folders) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('reaction_library_folders', folders);
    setState(() => _folders = folders);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasKey) {
      return ApiKeyScreen(
        store: _store,
        validator: _validator,
        onKeyAccepted: () => _checkSetup(),
      );
    }
    if (_folders.isEmpty) {
      return FolderSelectionScreen(onFoldersSelected: _onFoldersSelected);
    }
    return DevIndexingShell(apiKey: _apiKey!, folders: _folders);
  }
}

class DevIndexingShell extends StatefulWidget {
  const DevIndexingShell({
    super.key,
    required this.apiKey,
    required this.folders,
  });

  final String apiKey;
  final List<String> folders;

  @override
  State<DevIndexingShell> createState() => _DevIndexingShellState();
}

class _DevIndexingShellState extends State<DevIndexingShell> {
  IndexingPipeline? _pipeline;
  StreamSubscription<IndexingProgress>? _subscription;
  IndexingProgress? _progress;
  int _initialIndexedCount = 0;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _loadInitialCount();
  }

  Future<void> _loadInitialCount() async {
    final index = await ReactionIndex.open();
    final count = await index.count();
    await index.close();
    if (!mounted) return;
    setState(() => _initialIndexedCount = count);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pipeline?.stop();
    super.dispose();
  }

  void _startIndexing() {
    final pipeline = IndexingPipeline();
    setState(() {
      _pipeline = pipeline;
      _progress = null;
      _lastError = null;
    });
    _subscription = pipeline
        .start(apiKey: widget.apiKey, folderPaths: widget.folders)
        .listen(
      (progress) {
        setState(() {
          _progress = progress;
          if (progress.error != null) _lastError = progress.error;
        });
      },
      onDone: () {
        setState(() => _pipeline = null);
      },
      onError: (Object e) {
        setState(() {
          _pipeline = null;
          _lastError = '$e';
        });
      },
    );
  }

  Future<void> _stopIndexing() async {
    await _pipeline?.stop();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final running = _pipeline != null;
    final completedThisRun = progress?.completed ?? 0;
    final totalIndexed = _initialIndexedCount + completedThisRun;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Context GIF AI — dev'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$totalIndexed items indexed',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: running ? null : _startIndexing,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start full indexing'),
                ),
                const SizedBox(width: 12),
                if (running)
                  OutlinedButton.icon(
                    onPressed: _stopIndexing,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (progress != null) _ProgressView(progress: progress),
            if (_lastError != null) ...[
              const SizedBox(height: 16),
              Text('Last error: $_lastError',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.progress});

  final IndexingProgress progress;

  @override
  Widget build(BuildContext context) {
    final pct =
        progress.total == 0 ? 0.0 : progress.processed / progress.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(value: progress.done ? 1.0 : pct),
        const SizedBox(height: 12),
        Text(
          '${progress.processed} of ${progress.total} '
          '(${progress.completed} indexed, ${progress.skipped} skipped, '
          '${progress.failed} failed)',
        ),
        if (progress.currentItem != null) ...[
          const SizedBox(height: 8),
          Text(
            progress.currentItem!,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (progress.done) ...[
          const SizedBox(height: 12),
          Text('Done.', style: Theme.of(context).textTheme.titleMedium),
        ],
      ],
    );
  }
}
