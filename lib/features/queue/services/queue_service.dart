import '../../../data/database_helper.dart';
import '../../../data/models/episode.dart';
import '../../../data/models/queue_entry.dart';
import '../../../data/models/queued_episode.dart';

class QueueAddResult {
  const QueueAddResult({required this.addedCount, required this.skippedCount});

  final int addedCount;
  final int skippedCount;

  bool get addedAny => addedCount > 0;
}

class QueueService {
  const QueueService({required DatabaseHelper databaseHelper})
    : _databaseHelper = databaseHelper;

  final DatabaseHelper _databaseHelper;

  Future<List<QueuedEpisode>> loadQueue() async {
    return _databaseHelper.getQueuedEpisodes();
  }

  Future<QueueAddResult> addEpisodes(List<Episode> episodes) async {
    if (episodes.isEmpty) {
      return const QueueAddResult(addedCount: 0, skippedCount: 0);
    }

    final List<QueueEntry> existingQueue = await _databaseHelper.getQueue();
    final Set<String> existingGuids = existingQueue
        .map((QueueEntry entry) => entry.episodeGuid)
        .toSet();

    int nextSortOrder = existingQueue.isEmpty
        ? 0
        : existingQueue.last.sortOrder + 1;
    int addedCount = 0;
    int skippedCount = 0;

    final List<Episode> sortedEpisodes = List<Episode>.from(episodes)
      ..sort((Episode a, Episode b) => a.pubDate.compareTo(b.pubDate));

    for (final Episode episode in sortedEpisodes) {
      if (existingGuids.contains(episode.guid)) {
        skippedCount += 1;
        continue;
      }

      await _databaseHelper.enqueue(episode.guid, nextSortOrder);
      existingGuids.add(episode.guid);
      nextSortOrder += 1;
      addedCount += 1;
    }

    return QueueAddResult(addedCount: addedCount, skippedCount: skippedCount);
  }

  Future<void> removeQueuedEpisode(int queueId) async {
    await _databaseHelper.removeFromQueue(queueId);
    await _normalizeQueueOrder();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    final List<QueuedEpisode> queue = await _databaseHelper.getQueuedEpisodes();
    if (queue.isEmpty || oldIndex < 0 || oldIndex >= queue.length) {
      return;
    }

    int adjustedIndex = newIndex;
    if (adjustedIndex > oldIndex) {
      adjustedIndex -= 1;
    }
    if (adjustedIndex < 0 || adjustedIndex >= queue.length) {
      adjustedIndex = queue.length - 1;
    }

    final QueuedEpisode movedEpisode = queue.removeAt(oldIndex);
    queue.insert(adjustedIndex, movedEpisode);

    final List<QueueEntry> reorderedEntries = queue
        .asMap()
        .entries
        .map(
          (MapEntry<int, QueuedEpisode> entry) => QueueEntry(
            id: entry.value.queueId,
            episodeGuid: entry.value.episode.guid,
            sortOrder: entry.key,
          ),
        )
        .toList();

    await _databaseHelper.replaceQueueOrder(reorderedEntries);
  }

  /// Clears the entire queue and replaces it with [episodes] in the given order.
  /// Index 0 → sort_order 0 (plays first). Preserves display order exactly.
  Future<void> replaceQueueWithEpisodes(List<Episode> episodes) async {
    if (episodes.isEmpty) return;
    await _databaseHelper.clearQueue();
    for (int i = 0; i < episodes.length; i++) {
      await _databaseHelper.enqueue(episodes[i].guid, i);
    }
  }

  Future<void> _normalizeQueueOrder() async {
    final List<QueueEntry> queue = await _databaseHelper.getQueue();
    final List<QueueEntry> normalizedEntries = queue
        .asMap()
        .entries
        .map(
          (MapEntry<int, QueueEntry> entry) => QueueEntry(
            id: entry.value.id,
            episodeGuid: entry.value.episodeGuid,
            sortOrder: entry.key,
          ),
        )
        .toList();

    await _databaseHelper.replaceQueueOrder(normalizedEntries);
  }
}
