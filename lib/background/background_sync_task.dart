import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import '../data/database_helper.dart';
import '../data/models/episode.dart';
import '../data/models/podcast.dart';
import '../features/podcast_detail/services/rss_feed_service.dart';

// ── Public constants (imported by main.dart for registration) ─────────────────

const String kBackgroundSyncTaskName = 'minacast_daily_sync';
const String kNotificationChannelId = 'com.developingwoot.minacast.new_episodes';
const String kNotificationChannelName = 'New Episodes';

// ── WorkManager entry point ───────────────────────────────────────────────────

/// Top-level callback required by WorkManager. Must be annotated with
/// `@pragma('vm:entry-point')` so the Dart compiler does not tree-shake it
/// when building in release mode.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((String task, Map<String, dynamic>? inputData) async {
    try {
      final BackgroundSyncService service = BackgroundSyncService(
        databaseHelper: DatabaseHelper.instance,
        client: http.Client(),
      );
      return await service.runSyncTask();
    } catch (e) {
      // Per AGENTS.md: never let an uncaught exception crash the background isolate.
      if (kDebugMode) debugPrint('background_sync_task: unhandled error: $e');
      return Future.value(false);
    }
  });
}

// ── Service class ─────────────────────────────────────────────────────────────

/// Resolver for the downloads directory. Injectable so tests can provide a
/// temporary directory instead of calling [getApplicationSupportDirectory].
typedef DownloadDirResolver = Future<String> Function();

Future<String> _defaultDownloadDirResolver() async {
  final Directory appDir = await getApplicationSupportDirectory();
  final Directory downloadDir = Directory('${appDir.path}/downloads');
  if (!await downloadDir.exists()) {
    await downloadDir.create(recursive: true);
  }
  return downloadDir.path;
}

class BackgroundSyncService {
  BackgroundSyncService({
    required DatabaseHelper databaseHelper,
    required http.Client client,
    DownloadDirResolver? downloadDirResolver,
  })  : _db = databaseHelper,
        _client = client,
        _downloadDirResolver =
            downloadDirResolver ?? _defaultDownloadDirResolver;

  final DatabaseHelper _db;
  final http.Client _client;
  final DownloadDirResolver _downloadDirResolver;

  // ── Public entry point ──────────────────────────────────────────────────────

  Future<bool> runSyncTask() async {
    int totalNewEpisodes = 0;

    try {
      final List<Podcast> podcasts = await _db.getAllPodcasts();
      if (podcasts.isEmpty) return true;

      for (final Podcast podcast in podcasts) {
        // 5.1 — RSS sync
        final List<Episode> newEpisodes = await syncPodcast(podcast);
        totalNewEpisodes += newEpisodes.length;

        // 5.2 — Silent download
        await downloadOldestUnlistenedEpisode(podcast);
      }

      if (totalNewEpisodes > 0) {
        await _fireNewEpisodesNotification(totalNewEpisodes);
      }

      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('BackgroundSyncService.runSyncTask failed: $e');
      return false;
    }
  }

  // ── RSS sync ────────────────────────────────────────────────────────────────

  /// Fetches RSS for [podcast], inserts genuinely new episodes, and updates
  /// [Podcast.lastCheckedAt]. Returns only the episodes that were not already
  /// in the database. Exposed for testing.
  @visibleForTesting
  Future<List<Episode>> syncPodcast(Podcast podcast) async {
    try {
      final RssFeedService rssService = RssFeedService(client: _client);
      final PodcastFeedData feedData = await rssService.fetchFeed(
        podcast.rssUrl,
      );

      final List<Episode> newEpisodes = <Episode>[];
      for (final Episode episode in feedData.episodes) {
        final Episode? existing = await _db.getEpisodeByGuid(episode.guid);
        if (existing == null) {
          await _db.insertEpisode(episode);
          newEpisodes.add(episode);
        }
      }

      await _db.updatePodcastLastChecked(
        podcast.rssUrl,
        DateTime.now().millisecondsSinceEpoch,
      );

      return newEpisodes;
    } catch (e) {
      // One podcast failure must not abort the rest of the task.
      if (kDebugMode) {
        debugPrint('BackgroundSyncService.syncPodcast failed for ${podcast.rssUrl}: $e');
      }
      return <Episode>[];
    }
  }

  // ── Silent download ─────────────────────────────────────────────────────────

  /// Downloads the oldest unlistened episode (no local file yet) for [podcast].
  /// Streams the response to disk to avoid buffering the entire audio file in
  /// memory. Updates [Episode.localFilePath] in the DB on success.
  ///
  /// Uses [FileSystemException] as the storage safety net: if the device is
  /// out of space the write throws ENOSPC, we catch it and leave
  /// local_file_path null so playback falls back to streaming. See DECISIONS.md.
  ///
  /// Exposed for testing.
  @visibleForTesting
  Future<void> downloadOldestUnlistenedEpisode(Podcast podcast) async {
    try {
      final Episode? episode =
          await _db.getOldestUnlistenedEpisodeWithoutLocalFile(podcast.rssUrl);
      if (episode == null) return;

      final String downloadDir = await _downloadDirResolver();

      // Replace any character that isn't alphanumeric, dash, underscore, or
      // dot to prevent path traversal or invalid filenames on Android.
      final String safeFilename =
          '${episode.guid.replaceAll(RegExp(r'[^\w\-.]'), '_')}.mp3';
      final String filePath = '$downloadDir/$safeFilename';

      final http.StreamedResponse response = await _client.send(
        http.Request('GET', Uri.parse(episode.audioUrl)),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'BackgroundSyncService.downloadOldestUnlistenedEpisode: '
            'HTTP ${response.statusCode} for ${episode.audioUrl}',
          );
        }
        return;
      }

      final File file = File(filePath);
      final IOSink sink = file.openWrite();
      try {
        await response.stream.pipe(sink);
      } finally {
        await sink.close();
      }

      await _db.updateLocalFilePath(episode.guid, filePath);
    } on FileSystemException catch (e) {
      // Catches ENOSPC (out of disk space) and other filesystem errors.
      // Leaving local_file_path as null means playback will fall back to streaming.
      if (kDebugMode) {
        debugPrint(
          'BackgroundSyncService.downloadOldestUnlistenedEpisode: '
          'FileSystemException: $e',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'BackgroundSyncService.downloadOldestUnlistenedEpisode: error: $e',
        );
      }
    }
  }

  // ── Notification ────────────────────────────────────────────────────────────

  /// Shows a local notification summarising newly found episodes.
  /// Initialises a fresh plugin instance — required because this runs in a
  /// background isolate that does not share state with the main isolate.
  Future<void> _fireNewEpisodesNotification(int count) async {
    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
    );

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      kNotificationChannelId,
      kNotificationChannelName,
      channelDescription: 'New episode alerts',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    final String body = count == 1
        ? '1 new episode available'
        : '$count new episodes available';

    await plugin.show(
      id: 1001,
      title: 'Minacast',
      body: body,
      notificationDetails: const NotificationDetails(android: androidDetails),
    );
  }
}
