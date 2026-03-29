import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minacast/data/database_helper.dart';
import 'package:minacast/data/models/episode.dart';
import 'package:minacast/data/models/podcast.dart';
import 'package:minacast/features/playback/models/playback_progress.dart';
import 'package:minacast/features/playback/models/playback_ui_status.dart';
import 'package:minacast/features/playback/services/playback_persistence_coordinator.dart';

import 'fake_playback_controller.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.useInMemoryDatabaseForTests();
  });

  setUp(() async {
    await DatabaseHelper.instance.resetForTest();
  });

  Future<void> seedEpisode(Episode episode) async {
    await DatabaseHelper.instance.insertPodcast(
      const Podcast(
        rssUrl: 'https://example.com/feed.xml',
        title: 'Test Podcast',
        author: 'Host',
        description: 'Desc',
        artworkUrl: 'https://example.com/art.jpg',
        lastCheckedAt: 1,
      ),
    );
    await DatabaseHelper.instance.insertEpisode(episode);
  }

  test('coordinator persists every five seconds and flushes on pause', () async {
    final FakePlaybackController fakeController = FakePlaybackController();
    addTearDown(fakeController.dispose);

    const Episode episode = Episode(
      guid: 'episode-1',
      podcastRssUrl: 'https://example.com/feed.xml',
      title: 'Persistence Episode',
      audioUrl: 'https://example.com/episode.mp3',
      descriptionHtml: '<p>notes</p>',
      pubDate: 100,
    );
    await seedEpisode(episode);

    final PlaybackPersistenceCoordinator coordinator =
        PlaybackPersistenceCoordinator(
          controller: fakeController,
          databaseHelper: DatabaseHelper.instance,
        );
    addTearDown(coordinator.dispose);

    fakeController.emitEpisode(episode);
    fakeController.emitStatus(PlaybackUiStatus.playing);
    fakeController.emitProgress(
      const PlaybackProgress(
        position: Duration(seconds: 4),
        duration: Duration(seconds: 120),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      (await DatabaseHelper.instance.getEpisodeByGuid(episode.guid))!
          .listenedPositionSeconds,
      0,
    );

    fakeController.emitProgress(
      const PlaybackProgress(
        position: Duration(seconds: 5),
        duration: Duration(seconds: 120),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      (await DatabaseHelper.instance.getEpisodeByGuid(episode.guid))!
          .listenedPositionSeconds,
      5,
    );

    fakeController.emitProgress(
      const PlaybackProgress(
        position: Duration(seconds: 7),
        duration: Duration(seconds: 120),
      ),
    );
    fakeController.emitStatus(PlaybackUiStatus.paused);
    await Future<void>.delayed(Duration.zero);

    expect(
      (await DatabaseHelper.instance.getEpisodeByGuid(episode.guid))!
          .listenedPositionSeconds,
      7,
    );
  });

  test('coordinator flushes when app backgrounds', () async {
    final FakePlaybackController fakeController = FakePlaybackController();
    addTearDown(fakeController.dispose);

    const Episode episode = Episode(
      guid: 'episode-2',
      podcastRssUrl: 'https://example.com/feed.xml',
      title: 'Background Flush Episode',
      audioUrl: 'https://example.com/episode-2.mp3',
      descriptionHtml: '<p>notes</p>',
      pubDate: 100,
    );
    await seedEpisode(episode);

    final PlaybackPersistenceCoordinator coordinator =
        PlaybackPersistenceCoordinator(
          controller: fakeController,
          databaseHelper: DatabaseHelper.instance,
        );
    addTearDown(coordinator.dispose);

    fakeController.emitEpisode(episode);
    fakeController.emitStatus(PlaybackUiStatus.playing);
    fakeController.emitProgress(
      const PlaybackProgress(
        position: Duration(seconds: 11),
        duration: Duration(seconds: 240),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    await coordinator.handleAppLifecycleStateChanged(AppLifecycleState.paused);

    expect(
      (await DatabaseHelper.instance.getEpisodeByGuid(episode.guid))!
          .listenedPositionSeconds,
      11,
    );
  });
}
