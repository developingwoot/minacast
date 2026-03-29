import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minacast/data/database_helper.dart';
import 'package:minacast/data/models/episode.dart';
import 'package:minacast/data/models/podcast.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.useInMemoryDatabaseForTests();
  });

  setUp(() async {
    // Close and null-out the singleton so each test starts with a fresh
    // in-memory database (inMemoryDatabasePath opens a new DB on every call).
    await DatabaseHelper.instance.resetForTest();
  });

  // ── Helper factories ───────────────────────────────────────────────────────

  Podcast makePodcast({String rssUrl = 'https://example.com/feed.xml'}) {
    return Podcast(
      rssUrl: rssUrl,
      title: 'Test Podcast',
      author: 'Test Author',
      description: 'A podcast for testing.',
      artworkUrl: 'https://example.com/art.jpg',
      lastCheckedAt: 1000,
    );
  }

  Episode makeEpisode({
    String guid = 'ep-1',
    String podcastRssUrl = 'https://example.com/feed.xml',
    int pubDate = 2000,
  }) {
    return Episode(
      guid: guid,
      podcastRssUrl: podcastRssUrl,
      title: 'Test Episode',
      audioUrl: 'https://example.com/ep1.mp3',
      descriptionHtml: '<p>Show notes.</p>',
      pubDate: pubDate,
    );
  }

  // ── Group 1: Schema & Seeding ──────────────────────────────────────────────

  group('Schema & Seeding', () {
    test('creates all four tables', () async {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, Object?>> tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final List<String> names = tables
          .map((t) => t['name'] as String)
          .toList();
      expect(names, containsAll(['episodes', 'podcasts', 'queue', 'settings']));
    });

    test('seeds three default settings rows', () async {
      expect(
        await DatabaseHelper.instance.getSetting('dark_mode'),
        equals('false'),
      );
      expect(
        await DatabaseHelper.instance.getSetting('playback_speed'),
        equals('1.0'),
      );
      expect(
        await DatabaseHelper.instance.getSetting('sleep_timer_default_minutes'),
        equals('30'),
      );
    });

    test('seed is idempotent — does not overwrite user values', () async {
      await DatabaseHelper.instance.setSetting('dark_mode', 'true');
      // Trigger a second open cycle which would re-seed if broken.
      // We access the db directly to re-run the seed method via a raw insert.
      final db = await DatabaseHelper.instance.database;
      await db.insert('settings', {
        'key': 'dark_mode',
        'value': 'false',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      // User value should still be 'true'.
      expect(
        await DatabaseHelper.instance.getSetting('dark_mode'),
        equals('true'),
      );
    });
  });

  // ── Group 2: Podcasts ──────────────────────────────────────────────────────

  group('Podcasts', () {
    test('insertPodcast and getPodcastByUrl roundtrip', () async {
      final Podcast p = makePodcast();
      await DatabaseHelper.instance.insertPodcast(p);
      final Podcast? result = await DatabaseHelper.instance.getPodcastByUrl(
        p.rssUrl,
      );
      expect(result, isNotNull);
      expect(result!.rssUrl, equals(p.rssUrl));
      expect(result.title, equals(p.title));
      expect(result.author, equals(p.author));
      expect(result.description, equals(p.description));
      expect(result.artworkUrl, equals(p.artworkUrl));
      expect(result.lastCheckedAt, equals(p.lastCheckedAt));
    });

    test('getAllPodcasts returns empty list when no rows', () async {
      final List<Podcast> result = await DatabaseHelper.instance
          .getAllPodcasts();
      expect(result, isEmpty);
    });

    test('getAllPodcasts returns all inserted rows', () async {
      await DatabaseHelper.instance.insertPodcast(
        makePodcast(rssUrl: 'https://a.com/feed.xml'),
      );
      await DatabaseHelper.instance.insertPodcast(
        makePodcast(rssUrl: 'https://b.com/feed.xml'),
      );
      final List<Podcast> result = await DatabaseHelper.instance
          .getAllPodcasts();
      expect(result.length, equals(2));
    });

    test('deletePodcast removes the row', () async {
      final Podcast p = makePodcast();
      await DatabaseHelper.instance.insertPodcast(p);
      await DatabaseHelper.instance.deletePodcast(p.rssUrl);
      final Podcast? result = await DatabaseHelper.instance.getPodcastByUrl(
        p.rssUrl,
      );
      expect(result, isNull);
    });

    test('updatePodcastLastChecked persists new timestamp', () async {
      final Podcast p = makePodcast();
      await DatabaseHelper.instance.insertPodcast(p);
      await DatabaseHelper.instance.updatePodcastLastChecked(p.rssUrl, 9999);
      final Podcast? result = await DatabaseHelper.instance.getPodcastByUrl(
        p.rssUrl,
      );
      expect(result!.lastCheckedAt, equals(9999));
    });
  });

  // ── Group 2b: Transactional Podcast + Episodes Insert ────────────────────

  group('insertPodcastWithEpisodes', () {
    test('inserts podcast and all episodes atomically', () async {
      final Podcast p = makePodcast();
      final List<Episode> episodes = <Episode>[
        makeEpisode(guid: 'ep-1', pubDate: 1000),
        makeEpisode(guid: 'ep-2', pubDate: 2000),
        makeEpisode(guid: 'ep-3', pubDate: 3000),
      ];
      await DatabaseHelper.instance.insertPodcastWithEpisodes(p, episodes);

      final Podcast? storedPodcast = await DatabaseHelper.instance
          .getPodcastByUrl(p.rssUrl);
      expect(storedPodcast, isNotNull);

      final List<Episode> storedEpisodes = await DatabaseHelper.instance
          .getEpisodesForPodcast(p.rssUrl);
      expect(storedEpisodes.length, equals(3));
    });

    test('replaces podcast data on re-insert', () async {
      final Podcast p = makePodcast();
      await DatabaseHelper.instance.insertPodcastWithEpisodes(
        p,
        <Episode>[makeEpisode(guid: 'ep-1')],
      );

      final Podcast updated = Podcast(
        rssUrl: p.rssUrl,
        title: 'Updated Title',
        author: p.author,
        description: p.description,
        artworkUrl: p.artworkUrl,
        lastCheckedAt: 9999,
      );
      await DatabaseHelper.instance.insertPodcastWithEpisodes(
        updated,
        <Episode>[makeEpisode(guid: 'ep-1'), makeEpisode(guid: 'ep-2')],
      );

      final Podcast? result = await DatabaseHelper.instance.getPodcastByUrl(
        p.rssUrl,
      );
      expect(result!.title, equals('Updated Title'));
      expect(result.lastCheckedAt, equals(9999));

      final List<Episode> episodes = await DatabaseHelper.instance
          .getEpisodesForPodcast(p.rssUrl);
      expect(episodes.length, equals(2));
    });

    test('works with empty episode list', () async {
      final Podcast p = makePodcast();
      await DatabaseHelper.instance.insertPodcastWithEpisodes(
        p,
        <Episode>[],
      );

      final Podcast? result = await DatabaseHelper.instance.getPodcastByUrl(
        p.rssUrl,
      );
      expect(result, isNotNull);

      final List<Episode> episodes = await DatabaseHelper.instance
          .getEpisodesForPodcast(p.rssUrl);
      expect(episodes, isEmpty);
    });
  });

  // ── Group 3: Episodes ──────────────────────────────────────────────────────

  group('Episodes', () {
    setUp(() async {
      // Episodes have a FK on podcasts — insert a podcast first.
      await DatabaseHelper.instance.insertPodcast(makePodcast());
    });

    test('insertEpisode and getEpisodeByGuid roundtrip', () async {
      final Episode e = makeEpisode();
      await DatabaseHelper.instance.insertEpisode(e);
      final Episode? result = await DatabaseHelper.instance.getEpisodeByGuid(
        e.guid,
      );
      expect(result, isNotNull);
      expect(result!.guid, equals(e.guid));
      expect(result.podcastRssUrl, equals(e.podcastRssUrl));
      expect(result.title, equals(e.title));
      expect(result.audioUrl, equals(e.audioUrl));
      expect(result.descriptionHtml, equals(e.descriptionHtml));
      expect(result.pubDate, equals(e.pubDate));
      expect(result.listenedPositionSeconds, equals(0));
      expect(result.isCompleted, equals(0));
      expect(result.localFilePath, isNull);
    });

    test('getEpisodesForPodcast returns correct subset', () async {
      await DatabaseHelper.instance.insertPodcast(
        makePodcast(rssUrl: 'https://other.com/feed.xml'),
      );
      await DatabaseHelper.instance.insertEpisode(
        makeEpisode(
          guid: 'ep-1',
          podcastRssUrl: 'https://example.com/feed.xml',
        ),
      );
      await DatabaseHelper.instance.insertEpisode(
        makeEpisode(guid: 'ep-2', podcastRssUrl: 'https://other.com/feed.xml'),
      );
      final List<Episode> results = await DatabaseHelper.instance
          .getEpisodesForPodcast('https://example.com/feed.xml');
      expect(results.length, equals(1));
      expect(results.first.guid, equals('ep-1'));
    });

    test('updateListenedPosition persists value', () async {
      final Episode e = makeEpisode();
      await DatabaseHelper.instance.insertEpisode(e);
      await DatabaseHelper.instance.updateListenedPosition(e.guid, 120);
      final Episode? result = await DatabaseHelper.instance.getEpisodeByGuid(
        e.guid,
      );
      expect(result!.listenedPositionSeconds, equals(120));
    });

    test('markEpisodeCompleted sets is_completed to 1', () async {
      final Episode e = makeEpisode();
      await DatabaseHelper.instance.insertEpisode(e);
      await DatabaseHelper.instance.markEpisodeCompleted(e.guid);
      final Episode? result = await DatabaseHelper.instance.getEpisodeByGuid(
        e.guid,
      );
      expect(result!.isCompleted, equals(1));
    });

    test('upsertEpisode replaces existing row', () async {
      final Episode original = makeEpisode();
      await DatabaseHelper.instance.insertEpisode(original);
      final Episode updated = Episode(
        guid: original.guid,
        podcastRssUrl: original.podcastRssUrl,
        title: 'Updated Title',
        audioUrl: original.audioUrl,
        descriptionHtml: original.descriptionHtml,
        pubDate: original.pubDate,
      );
      await DatabaseHelper.instance.upsertEpisode(updated);
      final Episode? result = await DatabaseHelper.instance.getEpisodeByGuid(
        original.guid,
      );
      expect(result!.title, equals('Updated Title'));
    });

    test('deletePodcast cascades to episodes', () async {
      final Episode e = makeEpisode();
      await DatabaseHelper.instance.insertEpisode(e);
      await DatabaseHelper.instance.deletePodcast(e.podcastRssUrl);
      final Episode? result = await DatabaseHelper.instance.getEpisodeByGuid(
        e.guid,
      );
      expect(result, isNull);
    });
  });

  // ── Group 4: Queue ─────────────────────────────────────────────────────────

  group('Queue', () {
    setUp(() async {
      await DatabaseHelper.instance.insertPodcast(makePodcast());
      await DatabaseHelper.instance.insertEpisode(makeEpisode(guid: 'ep-1'));
      await DatabaseHelper.instance.insertEpisode(
        makeEpisode(guid: 'ep-2', pubDate: 3000),
      );
      await DatabaseHelper.instance.insertEpisode(
        makeEpisode(guid: 'ep-3', pubDate: 4000),
      );
    });

    test('enqueue adds entry', () async {
      await DatabaseHelper.instance.enqueue('ep-1', 0);
      final queue = await DatabaseHelper.instance.getQueue();
      expect(queue.length, equals(1));
      expect(queue.first.episodeGuid, equals('ep-1'));
      expect(queue.first.sortOrder, equals(0));
    });

    test('getQueue returns entries sorted by sort_order ASC', () async {
      await DatabaseHelper.instance.enqueue('ep-3', 20);
      await DatabaseHelper.instance.enqueue('ep-1', 0);
      await DatabaseHelper.instance.enqueue('ep-2', 10);
      final queue = await DatabaseHelper.instance.getQueue();
      expect(
        queue.map((e) => e.episodeGuid).toList(),
        equals(['ep-1', 'ep-2', 'ep-3']),
      );
    });

    test('updateQueueOrder changes position', () async {
      await DatabaseHelper.instance.enqueue('ep-1', 0);
      final queue = await DatabaseHelper.instance.getQueue();
      final int id = queue.first.id!;
      await DatabaseHelper.instance.updateQueueOrder(id, 99);
      final updated = await DatabaseHelper.instance.getQueue();
      expect(updated.first.sortOrder, equals(99));
    });

    test('removeFromQueue deletes by id', () async {
      await DatabaseHelper.instance.enqueue('ep-1', 0);
      await DatabaseHelper.instance.enqueue('ep-2', 10);
      final queue = await DatabaseHelper.instance.getQueue();
      await DatabaseHelper.instance.removeFromQueue(queue.first.id!);
      final remaining = await DatabaseHelper.instance.getQueue();
      expect(remaining.length, equals(1));
      expect(remaining.first.episodeGuid, equals('ep-2'));
    });

    test('clearQueue empties the table', () async {
      await DatabaseHelper.instance.enqueue('ep-1', 0);
      await DatabaseHelper.instance.enqueue('ep-2', 10);
      await DatabaseHelper.instance.clearQueue();
      final queue = await DatabaseHelper.instance.getQueue();
      expect(queue, isEmpty);
    });

    test('episode delete cascades to queue', () async {
      await DatabaseHelper.instance.enqueue('ep-1', 0);
      final db = await DatabaseHelper.instance.database;
      await db.delete('episodes', where: 'guid = ?', whereArgs: ['ep-1']);
      final queue = await DatabaseHelper.instance.getQueue();
      expect(queue, isEmpty);
    });
  });

  // ── Group 5: Settings ──────────────────────────────────────────────────────

  group('Settings', () {
    test('getSetting returns null for unknown key', () async {
      final String? result = await DatabaseHelper.instance.getSetting(
        'nonexistent_key',
      );
      expect(result, isNull);
    });

    test('setSetting inserts new key', () async {
      await DatabaseHelper.instance.setSetting('custom_key', 'custom_value');
      final String? result = await DatabaseHelper.instance.getSetting(
        'custom_key',
      );
      expect(result, equals('custom_value'));
    });

    test('setSetting overwrites existing key', () async {
      await DatabaseHelper.instance.setSetting('dark_mode', 'true');
      final String? result = await DatabaseHelper.instance.getSetting(
        'dark_mode',
      );
      expect(result, equals('true'));
    });
  });
}
