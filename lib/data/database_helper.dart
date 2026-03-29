import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'models/episode.dart';
import 'models/podcast.dart';
import 'models/queue_entry.dart';
import 'models/queued_episode.dart';

const String _dbName = 'minacast.db';
const int _dbVersion = 1;

const String _createPodcastsTable = '''
CREATE TABLE podcasts (
  rss_url         TEXT PRIMARY KEY,
  title           TEXT NOT NULL,
  author          TEXT NOT NULL,
  description     TEXT NOT NULL,
  artwork_url     TEXT NOT NULL,
  last_checked_at INTEGER NOT NULL
)
''';

const String _createEpisodesTable = '''
CREATE TABLE episodes (
  guid                      TEXT PRIMARY KEY,
  podcast_rss_url           TEXT NOT NULL,
  title                     TEXT NOT NULL,
  audio_url                 TEXT NOT NULL,
  description_html          TEXT NOT NULL,
  duration_seconds          INTEGER,
  pub_date                  INTEGER NOT NULL,
  listened_position_seconds INTEGER NOT NULL DEFAULT 0,
  is_completed              INTEGER NOT NULL DEFAULT 0,
  local_file_path           TEXT,
  FOREIGN KEY (podcast_rss_url) REFERENCES podcasts(rss_url) ON DELETE CASCADE
)
''';

const String _createQueueTable = '''
CREATE TABLE queue (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  episode_guid  TEXT NOT NULL,
  sort_order    INTEGER NOT NULL,
  FOREIGN KEY (episode_guid) REFERENCES episodes(guid) ON DELETE CASCADE
)
''';

const String _createSettingsTable = '''
CREATE TABLE settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''';

const List<Map<String, String>> _defaultSettings = [
  {'key': 'dark_mode', 'value': 'false'},
  {'key': 'playback_speed', 'value': '1.0'},
  {'key': 'sleep_timer_default_minutes', 'value': '30'},
];

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static Database? _db;

  /// When set, `_initDb` uses this path instead of the default on-disk path.
  /// Only set this in tests — use [resetForTest] to clear it.
  @visibleForTesting
  static String? testDbPath;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final String path = testDbPath ?? join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA journal_mode=WAL');
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (Database db, int version) async {
        await db.execute(_createPodcastsTable);
        await db.execute(_createEpisodesTable);
        await db.execute(_createQueueTable);
        await db.execute(_createSettingsTable);
        await _seedDefaultSettings(db);
      },
    );
  }

  Future<void> _seedDefaultSettings(Database db) async {
    for (final Map<String, String> row in _defaultSettings) {
      await db.insert(
        'settings',
        row,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ── Podcasts ──────────────────────────────────────────────────────────────

  Future<void> insertPodcast(Podcast podcast) async {
    try {
      final Database db = await database;
      await db.insert(
        'podcasts',
        podcast.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('insertPodcast failed: $e');
      rethrow;
    }
  }

  Future<Podcast?> getPodcastByUrl(String rssUrl) async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.query(
        'podcasts',
        where: 'rss_url = ?',
        whereArgs: [rssUrl],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Podcast.fromMap(rows.first);
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('getPodcastByUrl failed: $e');
      return null;
    }
  }

  Future<List<Podcast>> getAllPodcasts() async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.query('podcasts');
      return rows.map(Podcast.fromMap).toList();
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('getAllPodcasts failed: $e');
      return [];
    }
  }

  Future<void> updatePodcastLastChecked(String rssUrl, int timestampMs) async {
    try {
      final Database db = await database;
      await db.update(
        'podcasts',
        {'last_checked_at': timestampMs},
        where: 'rss_url = ?',
        whereArgs: [rssUrl],
      );
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('updatePodcastLastChecked failed: $e');
      rethrow;
    }
  }

  Future<void> deletePodcast(String rssUrl) async {
    try {
      final Database db = await database;
      await db.delete('podcasts', where: 'rss_url = ?', whereArgs: [rssUrl]);
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('deletePodcast failed: $e');
      rethrow;
    }
  }

  /// Inserts a podcast and all its episodes in a single transaction.
  /// If any insert fails, the entire operation is rolled back.
  Future<void> insertPodcastWithEpisodes(
    Podcast podcast,
    List<Episode> episodes,
  ) async {
    try {
      final Database db = await database;
      await db.transaction((Transaction txn) async {
        await txn.insert(
          'podcasts',
          podcast.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final Episode episode in episodes) {
          await txn.insert(
            'episodes',
            episode.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('insertPodcastWithEpisodes failed: $e');
      rethrow;
    }
  }

  // ── Episodes ──────────────────────────────────────────────────────────────

  Future<void> insertEpisode(Episode episode) async {
    try {
      final Database db = await database;
      await db.insert(
        'episodes',
        episode.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('insertEpisode failed: $e');
      rethrow;
    }
  }

  Future<void> upsertEpisode(Episode episode) async {
    try {
      final Database db = await database;
      await db.insert(
        'episodes',
        episode.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('upsertEpisode failed: $e');
      rethrow;
    }
  }

  Future<Episode?> getEpisodeByGuid(String guid) async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.query(
        'episodes',
        where: 'guid = ?',
        whereArgs: [guid],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Episode.fromMap(rows.first);
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('getEpisodeByGuid failed: $e');
      return null;
    }
  }

  Future<List<Episode>> getEpisodesForPodcast(String rssUrl) async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.query(
        'episodes',
        where: 'podcast_rss_url = ?',
        whereArgs: [rssUrl],
        orderBy: 'pub_date DESC',
      );
      return rows.map(Episode.fromMap).toList();
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('getEpisodesForPodcast failed: $e');
      return [];
    }
  }

  Future<List<Episode>> getAllEpisodesSortedByDate() async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.query(
        'episodes',
        orderBy: 'pub_date DESC',
      );
      return rows.map(Episode.fromMap).toList();
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('getAllEpisodesSortedByDate failed: $e');
      return [];
    }
  }

  Future<void> updateListenedPosition(String guid, int positionSeconds) async {
    try {
      final Database db = await database;
      await db.update(
        'episodes',
        {'listened_position_seconds': positionSeconds},
        where: 'guid = ?',
        whereArgs: [guid],
      );
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('updateListenedPosition failed: $e');
      rethrow;
    }
  }

  Future<void> markEpisodeCompleted(String guid) async {
    try {
      final Database db = await database;
      await db.update(
        'episodes',
        {'is_completed': 1},
        where: 'guid = ?',
        whereArgs: [guid],
      );
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('markEpisodeCompleted failed: $e');
      rethrow;
    }
  }

  Future<void> updateLocalFilePath(String guid, String path) async {
    try {
      final Database db = await database;
      await db.update(
        'episodes',
        {'local_file_path': path},
        where: 'guid = ?',
        whereArgs: [guid],
      );
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('updateLocalFilePath failed: $e');
      rethrow;
    }
  }

  /// Returns the oldest incomplete episode for [rssUrl] with no local file downloaded.
  /// "Oldest" means smallest pub_date — so the user works through a backlog in order.
  Future<Episode?> getOldestUnlistenedEpisodeWithoutLocalFile(
    String rssUrl,
  ) async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.query(
        'episodes',
        where:
            'podcast_rss_url = ? AND is_completed = 0 AND local_file_path IS NULL',
        whereArgs: [rssUrl],
        orderBy: 'pub_date ASC',
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return Episode.fromMap(rows.first);
    } on DatabaseException catch (e) {
      if (kDebugMode) {
        debugPrint('getOldestUnlistenedEpisodeWithoutLocalFile failed: $e');
      }
      return null;
    }
  }

  // ── Queue ─────────────────────────────────────────────────────────────────

  Future<void> enqueue(String episodeGuid, int sortOrder) async {
    try {
      final Database db = await database;
      await db.insert('queue', {
        'episode_guid': episodeGuid,
        'sort_order': sortOrder,
      });
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('enqueue failed: $e');
      rethrow;
    }
  }

  Future<List<QueueEntry>> getQueue() async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.query(
        'queue',
        orderBy: 'sort_order ASC',
      );
      return rows.map(QueueEntry.fromMap).toList();
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('getQueue failed: $e');
      return [];
    }
  }

  Future<QueueEntry?> getQueueEntryForEpisodeGuid(String episodeGuid) async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.query(
        'queue',
        where: 'episode_guid = ?',
        whereArgs: [episodeGuid],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return QueueEntry.fromMap(rows.first);
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('getQueueEntryForEpisodeGuid failed: $e');
      return null;
    }
  }

  Future<QueueEntry?> getNextQueueEntry() async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.query(
        'queue',
        orderBy: 'sort_order ASC',
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return QueueEntry.fromMap(rows.first);
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('getNextQueueEntry failed: $e');
      return null;
    }
  }

  Future<List<QueuedEpisode>> getQueuedEpisodes() async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.rawQuery('''
        SELECT
          queue.id AS queue_id,
          queue.sort_order AS queue_sort_order,
          episodes.guid,
          episodes.podcast_rss_url,
          episodes.title,
          episodes.audio_url,
          episodes.description_html,
          episodes.duration_seconds,
          episodes.pub_date,
          episodes.listened_position_seconds,
          episodes.is_completed,
          episodes.local_file_path,
          podcasts.title AS podcast_title,
          podcasts.artwork_url AS podcast_artwork_url
        FROM queue
        INNER JOIN episodes ON episodes.guid = queue.episode_guid
        INNER JOIN podcasts ON podcasts.rss_url = episodes.podcast_rss_url
        ORDER BY queue.sort_order ASC
      ''');
      return rows.map(QueuedEpisode.fromMap).toList();
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('getQueuedEpisodes failed: $e');
      return [];
    }
  }

  Future<void> updateQueueOrder(int id, int newSortOrder) async {
    try {
      final Database db = await database;
      await db.update(
        'queue',
        {'sort_order': newSortOrder},
        where: 'id = ?',
        whereArgs: [id],
      );
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('updateQueueOrder failed: $e');
      rethrow;
    }
  }

  Future<void> removeFromQueue(int id) async {
    try {
      final Database db = await database;
      await db.delete('queue', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('removeFromQueue failed: $e');
      rethrow;
    }
  }

  Future<void> clearQueue() async {
    try {
      final Database db = await database;
      await db.delete('queue');
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('clearQueue failed: $e');
      rethrow;
    }
  }

  Future<void> replaceQueueOrder(List<QueueEntry> entries) async {
    try {
      final Database db = await database;
      await db.transaction((Transaction transaction) async {
        for (final QueueEntry entry in entries) {
          await transaction.update(
            'queue',
            {'sort_order': entry.sortOrder},
            where: 'id = ?',
            whereArgs: [entry.id],
          );
        }
      });
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('replaceQueueOrder failed: $e');
      rethrow;
    }
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<String?> getSetting(String key) async {
    try {
      final Database db = await database;
      final List<Map<String, Object?>> rows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('getSetting failed: $e');
      return null;
    }
  }

  Future<void> setSetting(String key, String value) async {
    try {
      final Database db = await database;
      await db.insert('settings', {
        'key': key,
        'value': value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } on DatabaseException catch (e) {
      if (kDebugMode) debugPrint('setSetting failed: $e');
      rethrow;
    }
  }

  // ── Test helpers ──────────────────────────────────────────────────────────

  @visibleForTesting
  Future<void> resetForTest() async {
    await _db?.close();
    _db = null;
  }

  @visibleForTesting
  static void useInMemoryDatabaseForTests() {
    testDbPath = inMemoryDatabasePath;
  }
}
