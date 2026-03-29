import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minacast/data/database_helper.dart';
import 'package:minacast/data/models/episode.dart';
import 'package:minacast/data/models/podcast.dart';
import 'package:minacast/features/queue/services/queue_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.useInMemoryDatabaseForTests();
  });

  setUp(() async {
    await DatabaseHelper.instance.resetForTest();
    await DatabaseHelper.instance.insertPodcast(
      const Podcast(
        rssUrl: 'https://example.com/feed.xml',
        title: 'Queue Test Podcast',
        author: 'Host',
        description: 'Description',
        artworkUrl: 'https://example.com/art.jpg',
        lastCheckedAt: 1,
      ),
    );
    await DatabaseHelper.instance.insertEpisode(
      const Episode(
        guid: 'newest',
        podcastRssUrl: 'https://example.com/feed.xml',
        title: 'Newest',
        audioUrl: 'https://example.com/newest.mp3',
        descriptionHtml: '<p>Newest</p>',
        pubDate: 300,
      ),
    );
    await DatabaseHelper.instance.insertEpisode(
      const Episode(
        guid: 'oldest',
        podcastRssUrl: 'https://example.com/feed.xml',
        title: 'Oldest',
        audioUrl: 'https://example.com/oldest.mp3',
        descriptionHtml: '<p>Oldest</p>',
        pubDate: 100,
      ),
    );
    await DatabaseHelper.instance.insertEpisode(
      const Episode(
        guid: 'middle',
        podcastRssUrl: 'https://example.com/feed.xml',
        title: 'Middle',
        audioUrl: 'https://example.com/middle.mp3',
        descriptionHtml: '<p>Middle</p>',
        pubDate: 200,
      ),
    );
  });

  test('addEpisodes appends oldest-to-newest and skips duplicates', () async {
    final QueueService queueService = QueueService(
      databaseHelper: DatabaseHelper.instance,
    );
    final Episode newest = (await DatabaseHelper.instance.getEpisodeByGuid(
      'newest',
    ))!;
    final Episode oldest = (await DatabaseHelper.instance.getEpisodeByGuid(
      'oldest',
    ))!;
    final Episode middle = (await DatabaseHelper.instance.getEpisodeByGuid(
      'middle',
    ))!;

    final QueueAddResult firstResult = await queueService.addEpisodes(<Episode>[
      newest,
      oldest,
      middle,
    ]);
    final QueueAddResult duplicateResult = await queueService.addEpisodes(
      <Episode>[middle],
    );
    final queue = await DatabaseHelper.instance.getQueue();

    expect(firstResult.addedCount, 3);
    expect(firstResult.skippedCount, 0);
    expect(duplicateResult.addedCount, 0);
    expect(duplicateResult.skippedCount, 1);
    expect(queue.map((entry) => entry.episodeGuid).toList(), <String>[
      'oldest',
      'middle',
      'newest',
    ]);
  });

  test(
    'removeQueuedEpisode deletes row and normalizes remaining order',
    () async {
      final QueueService queueService = QueueService(
        databaseHelper: DatabaseHelper.instance,
      );
      await DatabaseHelper.instance.enqueue('oldest', 0);
      await DatabaseHelper.instance.enqueue('middle', 1);
      await DatabaseHelper.instance.enqueue('newest', 2);

      final beforeRemoval = await DatabaseHelper.instance.getQueue();
      await queueService.removeQueuedEpisode(beforeRemoval[1].id!);
      final afterRemoval = await DatabaseHelper.instance.getQueue();

      expect(afterRemoval, hasLength(2));
      expect(afterRemoval[0].sortOrder, 0);
      expect(afterRemoval[1].sortOrder, 1);
      expect(afterRemoval.map((entry) => entry.episodeGuid).toList(), <String>[
        'oldest',
        'newest',
      ]);
    },
  );

  test('reorderQueue persists the new queue order', () async {
    final QueueService queueService = QueueService(
      databaseHelper: DatabaseHelper.instance,
    );
    await DatabaseHelper.instance.enqueue('oldest', 0);
    await DatabaseHelper.instance.enqueue('middle', 1);
    await DatabaseHelper.instance.enqueue('newest', 2);

    await queueService.reorderQueue(0, 3);
    final reorderedQueue = await DatabaseHelper.instance.getQueue();

    expect(reorderedQueue.map((entry) => entry.episodeGuid).toList(), <String>[
      'middle',
      'newest',
      'oldest',
    ]);
    expect(reorderedQueue.map((entry) => entry.sortOrder).toList(), <int>[
      0,
      1,
      2,
    ]);
  });
}
