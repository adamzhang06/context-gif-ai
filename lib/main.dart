import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_key_store/api_key_screen.dart';
import 'api_key_store/api_key_store.dart';
import 'api_key_store/gemini_key_validator.dart';
import 'gemini_service/gemini_service.dart';
import 'indexing_pipeline/indexer.dart';
import 'library_scanner/folder_selection_screen.dart';
import 'library_scanner/library_scanner.dart';
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
  ReactionIndex? _index;
  Indexer? _indexer;
  int _indexedCount = 0;
  ReactionMediaRow? _lastResult;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final index = await ReactionIndex.open();
    final gemini = GeminiService(widget.apiKey);
    final indexer = Indexer(gemini: gemini, index: index);
    final count = await index.count();
    setState(() {
      _index = index;
      _indexer = indexer;
      _indexedCount = count;
    });
  }

  @override
  void dispose() {
    _index?.close();
    super.dispose();
  }

  Future<void> _indexOne() async {
    if (_index == null || _indexer == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final scanner = LibraryScanner();
      final files = await scanner.scan(widget.folders);
      String? next;
      for (final f in files) {
        if (f.toLowerCase().endsWith('.mp4')) continue;
        final existing = await _index!.findByPath(f);
        if (existing == null) {
          next = f;
          break;
        }
      }
      if (next == null) {
        setState(() {
          _busy = false;
          _error = 'All non-video items already indexed.';
        });
        return;
      }
      final row = await _indexer!.indexFile(next);
      final count = await _index!.count();
      setState(() {
        _lastResult = row;
        _indexedCount = count;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text('$_indexedCount items indexed',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _indexOne,
              icon: _busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Index one item'),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (_lastResult != null) _LastResultCard(row: _lastResult!),
          ],
        ),
      ),
    );
  }
}

class _LastResultCard extends StatelessWidget {
  const _LastResultCard({required this.row});

  final ReactionMediaRow row;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.path,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Chip(label: Text('category: ${row.category}')),
            const SizedBox(height: 12),
            Text(row.caption),
            const SizedBox(height: 12),
            Text(
              'embedding: ${row.embedding.length} dims',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
