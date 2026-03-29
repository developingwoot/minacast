import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/episode.dart';
import '../../../data/models/queued_episode.dart';
import '../../../data/providers/database_provider.dart';
import '../services/queue_service.dart';

final Provider<QueueService> queueServiceProvider = Provider<QueueService>((
  Ref ref,
) {
  return QueueService(databaseHelper: ref.watch(databaseHelperProvider));
});

class QueueNotifier extends AsyncNotifier<List<QueuedEpisode>> {
  QueueService get _queueService => ref.read(queueServiceProvider);

  @override
  Future<List<QueuedEpisode>> build() async {
    return _queueService.loadQueue();
  }

  Future<QueueAddResult> addEpisode(Episode episode) async {
    final QueueAddResult result = await _queueService.addEpisodes(<Episode>[
      episode,
    ]);
    await _reloadQueue();
    return result;
  }

  Future<void> removeQueuedEpisode(int queueId) async {
    await _queueService.removeQueuedEpisode(queueId);
    await _reloadQueue();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    await _queueService.reorderQueue(oldIndex, newIndex);
    await _reloadQueue();
  }

  Future<void> _reloadQueue() async {
    state = const AsyncLoading<List<QueuedEpisode>>();
    state = await AsyncValue.guard(_queueService.loadQueue);
  }
}

final AsyncNotifierProvider<QueueNotifier, List<QueuedEpisode>> queueProvider =
    AsyncNotifierProvider<QueueNotifier, List<QueuedEpisode>>(
      QueueNotifier.new,
    );
