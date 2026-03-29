import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minacast/background/background_sync_task.dart';
import 'package:minacast/data/database_helper.dart';
import 'package:minacast/data/models/episode.dart';
import 'package:minacast/data/models/podcast.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

Podcast makePodcast({String rssUrl = 'https://example.com/feed.xml'}) {
  return Podcast(
    rssUrl: rssUrl,
    title: 'Test Podcast',
    author: 'Author',
    description: 'Desc',
    artworkUrl: 'https://example.com/art.jpg',
    lastCheckedAt: 0,
  );
}

Episode makeEpisode({
  String guid = 'ep-1',
  String podcastRssUrl = 'https://example.com/feed.xml',
  int pubDate = 1000,
  int isCompleted = 0,
}) {
  return Episode(
    guid: guid,
    podcastRssUrl: podcastRssUrl,
    title: 'Episode $guid',
    audioUrl: 'https://example.com/$guid.mp3',
    descriptionHtml: '',
    pubDate: pubDate,
  );
}

/// Returns RSS XML containing one episode with the given [guid].
String makeRssXml(String guid) => '''
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Test Podcast</title>
    <description>Desc</description>
    <item>
      <guid>$guid</guid>
      <title>Episode $guid</title>
      <pubDate>Mon, 01 Jan 2024 00:00:00 +0000</pubDate>
      <enclosure url="https://example.com/$guid.mp3" type="audio/mpeg" />
    </item>
  </channel>
</rss>
''';

// ── Test suite ────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.useInMemoryDatabaseForTests();
  });

  setUp(() async {
    await DatabaseHelper.instance.resetForTest();
  });

  // ── syncPodcast ─────────────────────────────────────────────────────────────

  group('syncPodcast', () {
    test('inserts new episodes that do not exist in DB', () async {
      await DatabaseHelper.instance.insertPodcast(makePodcast());

      final BackgroundSyncService service = BackgroundSyncService(
        databaseHelper: DatabaseHelper.instance,
        client: MockClient(
          (_) async => http.Response(makeRssXml('new-ep'), 200),
        ),
      );

      final List<Episode> newEpisodes = await service.syncPodcast(makePodcast());

      expect(newEpisodes, hasLength(1));
      expect(newEpisodes.first.guid, equals('new-ep'));

      final Episode? stored = await DatabaseHelper.instance.getEpisodeByGuid(
        'new-ep',
      );
      expect(stored, isNotNull);
    });

    test('skips episodes that already exist in DB', () async {
      await DatabaseHelper.instance.insertPodcast(makePodcast());
      // Pre-insert the episode so it already exists.
      await DatabaseHelper.instance.insertEpisode(makeEpisode(guid: 'existing'));

      final BackgroundSyncService service = BackgroundSyncService(
        databaseHelper: DatabaseHelper.instance,
        client: MockClient(
          (_) async => http.Response(makeRssXml('existing'), 200),
        ),
      );

      final List<Episode> newEpisodes = await service.syncPodcast(makePodcast());

      expect(newEpisodes, isEmpty);
    });

    test('updates last_checked_at on podcast after sync', () async {
      await DatabaseHelper.instance.insertPodcast(makePodcast());

      final int before = DateTime.now().millisecondsSinceEpoch;

      final BackgroundSyncService service = BackgroundSyncService(
        databaseHelper: DatabaseHelper.instance,
        client: MockClient(
          (_) async => http.Response(makeRssXml('any-ep'), 200),
        ),
      );

      await service.syncPodcast(makePodcast());

      final Podcast? updated = await DatabaseHelper.instance.getPodcastByUrl(
        'https://example.com/feed.xml',
      );
      expect(updated, isNotNull);
      expect(updated!.lastCheckedAt, greaterThanOrEqualTo(before));
    });

    test('returns empty list when RSS fetch returns non-200', () async {
      await DatabaseHelper.instance.insertPodcast(makePodcast());

      final BackgroundSyncService service = BackgroundSyncService(
        databaseHelper: DatabaseHelper.instance,
        client: MockClient((_) async => http.Response('', 500)),
      );

      final List<Episode> newEpisodes = await service.syncPodcast(makePodcast());

      expect(newEpisodes, isEmpty);
    });

    test('returns empty list when RSS fetch throws an exception', () async {
      await DatabaseHelper.instance.insertPodcast(makePodcast());

      final BackgroundSyncService service = BackgroundSyncService(
        databaseHelper: DatabaseHelper.instance,
        client: MockClient((_) async => throw const SocketException('offline')),
      );

      final List<Episode> newEpisodes = await service.syncPodcast(makePodcast());

      expect(newEpisodes, isEmpty);
    });
  });

  // ── downloadOldestUnlistenedEpisode ─────────────────────────────────────────

  group('downloadOldestUnlistenedEpisode', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('minacast_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    BackgroundSyncService makeService(http.Client client) {
      return BackgroundSyncService(
        databaseHelper: DatabaseHelper.instance,
        client: client,
        downloadDirResolver: () async => tempDir.path,
      );
    }

    test('writes file to disk and updates local_file_path on HTTP 200',
        () async {
      final Podcast podcast = makePodcast();
      await DatabaseHelper.instance.insertPodcast(podcast);
      await DatabaseHelper.instance.insertEpisode(makeEpisode(guid: 'dl-ep'));

      const String fakeAudioContent = 'fake audio bytes';

      final BackgroundSyncService service = makeService(
        MockClient((http.Request request) async {
          return http.Response(fakeAudioContent, 200);
        }),
      );

      await service.downloadOldestUnlistenedEpisode(podcast);

      final Episode? updated = await DatabaseHelper.instance.getEpisodeByGuid(
        'dl-ep',
      );
      expect(updated, isNotNull);
      expect(updated!.localFilePath, isNotNull);
      expect(await File(updated.localFilePath!).exists(), isTrue);
    });

    test('does not update local_file_path when HTTP response is not 200',
        () async {
      final Podcast podcast = makePodcast();
      await DatabaseHelper.instance.insertPodcast(podcast);
      await DatabaseHelper.instance.insertEpisode(makeEpisode(guid: 'fail-ep'));

      final BackgroundSyncService service = makeService(
        MockClient((_) async => http.Response('Not Found', 404)),
      );

      await service.downloadOldestUnlistenedEpisode(podcast);

      final Episode? unchanged = await DatabaseHelper.instance.getEpisodeByGuid(
        'fail-ep',
      );
      expect(unchanged!.localFilePath, isNull);
    });

    test('does nothing when no unlistened episode without local file exists',
        () async {
      final Podcast podcast = makePodcast();
      await DatabaseHelper.instance.insertPodcast(podcast);

      // Episode already has a local file — should be skipped.
      final Episode ep = makeEpisode(guid: 'already-downloaded');
      await DatabaseHelper.instance.insertEpisode(ep);
      await DatabaseHelper.instance.updateLocalFilePath(
        ep.guid,
        '/some/path/already-downloaded.mp3',
      );

      bool clientCalled = false;
      final BackgroundSyncService service = makeService(
        MockClient((_) async {
          clientCalled = true;
          return http.Response('', 200);
        }),
      );

      await service.downloadOldestUnlistenedEpisode(podcast);

      expect(clientCalled, isFalse);
    });

    test('handles FileSystemException without throwing', () async {
      final Podcast podcast = makePodcast();
      await DatabaseHelper.instance.insertPodcast(podcast);
      await DatabaseHelper.instance.insertEpisode(makeEpisode(guid: 'fs-ep'));

      // Use an invalid path to provoke a FileSystemException.
      final BackgroundSyncService service = BackgroundSyncService(
        databaseHelper: DatabaseHelper.instance,
        client: MockClient((_) async => http.Response('data', 200)),
        // Point to a path that cannot be written to (a file, not a directory).
        downloadDirResolver: () async {
          final File blocker = File('${tempDir.path}/blocker');
          await blocker.writeAsString('not a directory');
          return blocker.path; // treating a file path as a dir will fail on write
        },
      );

      // Must not throw.
      await expectLater(
        service.downloadOldestUnlistenedEpisode(podcast),
        completes,
      );

      // local_file_path must not have been updated.
      final Episode? unchanged = await DatabaseHelper.instance.getEpisodeByGuid(
        'fs-ep',
      );
      expect(unchanged!.localFilePath, isNull);
    });
  });
}
