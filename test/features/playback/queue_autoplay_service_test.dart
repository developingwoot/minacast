import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minacast/data/database_helper.dart';
import 'package:minacast/data/models/episode.dart';
import 'package:minacast/data/models/podcast.dart';
import 'package:minacast/features/playback/services/queue_autoplay_service.dart';

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
        title: 'Autoplay Podcast',
        author: 'Host',
        description: 'Description',
        artworkUrl: 'https://example.com/art.jpg',
        lastCheckedAt: 1,
      ),
    );
    await DatabaseHelper.instance.insertEpisode(
      const Episode(
        guid: 'current',
        podcastRssUrl: 'https://example.com/feed.xml',
        title: 'Current Episode',
        audioUrl: 'https://example.com/current.mp3',
        descriptionHtml: '<p>Current</p>',
        pubDate: 100,
      ),
    );
    await DatabaseHelper.instance.insertEpisode(
      const Episode(
        guid: 'next',
        podcastRssUrl: 'https://example.com/feed.xml',
        title: 'Next Episode',
        audioUrl: 'https://example.com/next.mp3',
        descriptionHtml: '<p>Next</p>',
        pubDate: 200,
      ),
    );
  });

  test(
    'completeEpisodeAndLoadNext removes finished entry and returns next queued episode',
    () async {
      final QueueAutoplayService queueAutoplayService = QueueAutoplayService(
        databaseHelper: DatabaseHelper.instance,
      );
      final Episode currentEpisode = (await DatabaseHelper.instance
          .getEpisodeByGuid('current'))!;

      await DatabaseHelper.instance.enqueue('current', 0);
      await DatabaseHelper.instance.enqueue('next', 1);

      final Episode? nextEpisode = await queueAutoplayService
          .completeEpisodeAndLoadNext(currentEpisode);
      final Episode? storedCurrentEpisode = await DatabaseHelper.instance
          .getEpisodeByGuid('current');
      final queue = await DatabaseHelper.instance.getQueue();

      expect(nextEpisode, isNotNull);
      expect(nextEpisode!.guid, 'next');
      expect(storedCurrentEpisode!.isCompleted, 1);
      expect(storedCurrentEpisode.listenedPositionSeconds, 0);
      expect(queue, hasLength(1));
      expect(queue.first.episodeGuid, 'next');
    },
  );

  test(
    'completeEpisodeAndLoadNext stops after marking completion when episode is not queued',
    () async {
      final QueueAutoplayService queueAutoplayService = QueueAutoplayService(
        databaseHelper: DatabaseHelper.instance,
      );
      final Episode currentEpisode = (await DatabaseHelper.instance
          .getEpisodeByGuid('current'))!;

      final Episode? nextEpisode = await queueAutoplayService
          .completeEpisodeAndLoadNext(currentEpisode);
      final Episode? storedCurrentEpisode = await DatabaseHelper.instance
          .getEpisodeByGuid('current');

      expect(nextEpisode, isNull);
      expect(storedCurrentEpisode, isNotNull);
      expect(storedCurrentEpisode!.isCompleted, 1);
      expect(storedCurrentEpisode.listenedPositionSeconds, 0);
    },
  );
}
