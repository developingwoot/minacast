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
}
