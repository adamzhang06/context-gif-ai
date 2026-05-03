class IndexingProgress {
  const IndexingProgress({
    required this.completed,
    required this.skipped,
    required this.failed,
    required this.total,
    required this.done,
    this.currentItem,
    this.error,
  });

  final int completed;
  final int skipped;
  final int failed;
  final int total;
  final bool done;
  final String? currentItem;
  final String? error;

  int get processed => completed + skipped + failed;

  Map<String, Object?> toMap() => {
        'completed': completed,
        'skipped': skipped,
        'failed': failed,
        'total': total,
        'done': done,
        'currentItem': currentItem,
        'error': error,
      };

  factory IndexingProgress.fromMap(Map<String, Object?> m) => IndexingProgress(
        completed: m['completed'] as int,
        skipped: m['skipped'] as int,
        failed: m['failed'] as int,
        total: m['total'] as int,
        done: m['done'] as bool,
        currentItem: m['currentItem'] as String?,
        error: m['error'] as String?,
      );
}
