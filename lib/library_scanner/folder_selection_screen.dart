import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'library_scanner.dart';

class FolderSelectionScreen extends StatefulWidget {
  const FolderSelectionScreen({
    super.key,
    required this.onFoldersSelected,
    this.initialFolders = const [],
  });

  final void Function(List<String> folders) onFoldersSelected;
  final List<String> initialFolders;

  @override
  State<FolderSelectionScreen> createState() => _FolderSelectionScreenState();
}

class _FolderSelectionScreenState extends State<FolderSelectionScreen> {
  final _scanner = LibraryScanner();
  late List<String> _folders;
  int? _itemCount;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _folders = List.of(widget.initialFolders);
    if (_folders.isNotEmpty) _scan();
  }

  Future<void> _addFolder() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null || _folders.contains(path)) return;
    setState(() => _folders.add(path));
    await _scan();
  }

  Future<void> _removeFolder(String path) async {
    setState(() {
      _folders.remove(path);
      _itemCount = null;
    });
    if (_folders.isNotEmpty) await _scan();
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final files = await _scanner.scan(_folders);
    if (!mounted) return;
    setState(() {
      _itemCount = files.length;
      _scanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Reaction Library')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pick the folders where your reaction media lives. '
              'The app scans for images and videos — nothing is moved or copied.',
            ),
            const SizedBox(height: 24),
            if (_folders.isEmpty)
              const Text('No folders selected yet.',
                  style: TextStyle(color: Colors.grey))
            else
              ..._folders.map(
                (f) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(f, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove',
                    onPressed: () => _removeFolder(f),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addFolder,
              icon: const Icon(Icons.add),
              label: const Text('Add folder'),
            ),
            const SizedBox(height: 24),
            if (_scanning)
              const Row(children: [
                SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Scanning…'),
              ])
            else if (_itemCount != null)
              Text(
                '$_itemCount item${_itemCount == 1 ? '' : 's'} found',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _folders.isNotEmpty && !_scanning
                    ? () => widget.onFoldersSelected(_folders)
                    : null,
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
