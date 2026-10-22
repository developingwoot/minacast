import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minacast/data/database_helper.dart';
import 'package:minacast/data/models/episode.dart';
import 'package:minacast/data/models/podcast.dart';
import 'package:minacast/data/models/queue_entry.dart';

const String _rssUrl = 'https://example.com/feed.xml';

Podcast _podcast({String title = 'Test Podcast'}) {
  return Podcast(
    rssUrl: _rssUrl,
    title: title,
    author: 'Test Author',
    description: 'A podcast for testing.',
    artworkUrl: 'https://example.com/art.jpg',
    lastCheckedAt: 1000,
  );
}

Episode _episode(
  String guid, {
  String title = 'Episode',
  int listened = 0,
  int completed = 0,
  String? localFilePath,
}) {
  return Episode(
    guid: guid,
    podcastRssUrl: _rssUrl,
    title: title,
    audioUrl: 'https://example.com/$guid.mp3',
    descriptionHtml: '<p>Notes</p>',
    pubDate: 2000,
    listenedPositionSeconds: listened,
    isCompleted: completed,
    localFilePath: localFilePath,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('re-inserting existing rows must not wipe user state', () {
    setUp(() async {
      DatabaseHelper.useInMemoryDatabaseForTests();
      await DatabaseHelper.instance.resetForTest();
    });

    Future<void> seedUserState() async {
      final DatabaseHelper db = DatabaseHelper.instance;
      await db.insertPodcastWithEpisodes(_podcast(), <Episode>[
        _episode('ep-1'),
        _episode('ep-2'),
      ]);
      await db.updateListenedPosition('ep-1', 120);
      await db.updateLocalFilePath('ep-1', '/data/ep-1.mp3');
      await db.markEpisodeCompleted('ep-2');
      await db.enqueue('ep-1', 0);
      await db.enqueue('ep-2', 1);
    }

    test('insertPodcast keeps episodes and queue rows', () async {
      await seedUserState();

      await DatabaseHelper.instance.insertPodcast(_podcast(title: 'Renamed'));

      final DatabaseHelper db = DatabaseHelper.instance;
      expect((await db.getPodcastByUrl(_rssUrl))!.title, 'Renamed');
      expect(await db.getEpisodeByGuid('ep-1'), isNotNull);
      expect(await db.getEpisodeByGuid('ep-2'), isNotNull);
      final List<QueueEntry> queue = await db.getQueue();
      expect(queue.map((QueueEntry e) => e.episodeGuid), <String>[
        'ep-1',
        'ep-2',
      ]);
    });

    test(
      'insertPodcastWithEpisodes keeps progress, completion, download and queue',
      () async {
        await seedUserState();

        // Fresh feed data for the same podcast, as a re-subscribe would send.
        await DatabaseHelper.instance
            .insertPodcastWithEpisodes(_podcast(title: 'Renamed'), <Episode>[
              _episode('ep-1', title: 'Fresh title'),
              _episode('ep-2'),
              _episode('ep-3'),
            ]);

        final DatabaseHelper db = DatabaseHelper.instance;
        final Episode ep1 = (await db.getEpisodeByGuid('ep-1'))!;
        expect(ep1.title, 'Fresh title');
        expect(ep1.listenedPositionSeconds, 120);
        expect(ep1.localFilePath, '/data/ep-1.mp3');
        expect((await db.getEpisodeByGuid('ep-2'))!.isCompleted, 1);
        expect(await db.getEpisodeByGuid('ep-3'), isNotNull);
        expect((await db.getQueue()).length, 2);
      },
    );

    test(
      'upsertEpisode updates metadata but keeps user state and queue',
      () async {
        await seedUserState();

        await DatabaseHelper.instance.upsertEpisode(
          _episode('ep-1', title: 'Fresh title'),
        );

        final DatabaseHelper db = DatabaseHelper.instance;
        final Episode ep1 = (await db.getEpisodeByGuid('ep-1'))!;
        expect(ep1.title, 'Fresh title');
        expect(ep1.listenedPositionSeconds, 120);
        expect(ep1.localFilePath, '/data/ep-1.mp3');
        expect((await db.getQueue()).length, 2);
      },
    );

    test('upsertEpisode inserts an episode that does not exist yet', () async {
      await DatabaseHelper.instance.insertPodcast(_podcast());

      await DatabaseHelper.instance.upsertEpisode(_episode('ep-new'));

      expect(
        await DatabaseHelper.instance.getEpisodeByGuid('ep-new'),
        isNotNull,
      );
    });
  });

  group('WAL mode', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('minacast_wal_test');
      DatabaseHelper.testDbPath = '${tempDir.path}/wal_test.db';
      await DatabaseHelper.instance.resetForTest();
    });

    tearDown(() async {
      await DatabaseHelper.instance.resetForTest();
      DatabaseHelper.useInMemoryDatabaseForTests();
      await tempDir.delete(recursive: true);
    });

    test('file-backed database opens in WAL journal mode', () async {
      final Database db = await DatabaseHelper.instance.database;

      final List<Map<String, Object?>> rows = await db.rawQuery(
        'PRAGMA journal_mode',
      );

      expect(rows.first['journal_mode'], 'wal');
    });
  });
}
