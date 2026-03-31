import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../data/database_helper.dart';
import '../../../data/models/episode.dart';
import '../../../data/models/queue_entry.dart';

class QueueAutoplayService {
  const QueueAutoplayService({required DatabaseHelper databaseHelper})
    : _databaseHelper = databaseHelper;

  final DatabaseHelper _databaseHelper;

  Future<Episode?> completeEpisodeAndLoadNext(Episode completedEpisode) async {
    await _databaseHelper.markEpisodeCompleted(completedEpisode.guid);
    await _databaseHelper.updateListenedPosition(completedEpisode.guid, 0);
    await _deleteLocalFileIfPresent(completedEpisode);

    final QueueEntry? completedQueueEntry = await _databaseHelper
        .getQueueEntryForEpisodeGuid(completedEpisode.guid);
    if (completedQueueEntry == null) {
      return null;
    }

    await _databaseHelper.removeFromQueue(completedQueueEntry.id!);

    final QueueEntry? nextQueueEntry = await _databaseHelper
        .getNextQueueEntry();
    if (nextQueueEntry == null) {
      return null;
    }

    return _databaseHelper.getEpisodeByGuid(nextQueueEntry.episodeGuid);
  }

  Future<void> _deleteLocalFileIfPresent(Episode episode) async {
    final String? localPath = episode.localFilePath;
    if (localPath == null) return;
    try {
      final File file = File(localPath);
      if (await file.exists()) await file.delete();
      await _databaseHelper.clearLocalFilePath(episode.guid);
    } catch (e) {
      if (kDebugMode) debugPrint('QueueAutoplayService: failed to delete local file: $e');
    }
  }
}
