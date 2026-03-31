import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../data/database_helper.dart';
import '../../../data/models/episode.dart';

const int _kMaxOnOpenDownloads = 3;

/// Runs once at app open: if on WiFi, downloads up to [_kMaxOnOpenDownloads]
/// undownloaded episodes, prioritising the queue over the home feed.
class OnOpenDownloadService {
  OnOpenDownloadService({
    required DatabaseHelper databaseHelper,
    http.Client? client,
  }) : _db = databaseHelper,
       _client = client ?? http.Client();

  final DatabaseHelper _db;
  final http.Client _client;

  Future<void> run() async {
    try {
      final bool onWifi = await _isOnWifi();
      if (!onWifi) return;

      final List<Episode> candidates = await _buildCandidates();
      if (candidates.isEmpty) return;

      final String downloadDir = await _resolveDownloadDir();

      for (final Episode episode in candidates) {
        await _downloadEpisode(episode, downloadDir);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('OnOpenDownloadService.run failed: $e');
    }
  }

  Future<bool> _isOnWifi() async {
    final List<ConnectivityResult> results =
        await Connectivity().checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Builds a download candidate list: queue episodes first, then feed episodes.
  /// Only downloads enough to bring the total downloaded count up to [_kMaxOnOpenDownloads].
  Future<List<Episode>> _buildCandidates() async {
    final int alreadyDownloaded = await _db.getDownloadedEpisodeCount();
    final int slotsRemaining = _kMaxOnOpenDownloads - alreadyDownloaded;
    if (slotsRemaining <= 0) return <Episode>[];

    final List<Episode> candidates = <Episode>[];

    // Queue episodes first (in sort order)
    final List<Episode> queueCandidates = await _getQueueEpisodesWithoutFile();
    for (final Episode e in queueCandidates) {
      if (candidates.length >= slotsRemaining) break;
      candidates.add(e);
    }

    if (candidates.length >= slotsRemaining) return candidates;

    // Fill remaining slots from the home feed (newest first)
    final Set<String> alreadyIncluded = candidates.map((Episode e) => e.guid).toSet();
    final List<Episode> feedEpisodes = await _db.getAllEpisodesSortedByDate();
    for (final Episode e in feedEpisodes) {
      if (candidates.length >= slotsRemaining) break;
      if (alreadyIncluded.contains(e.guid)) continue;
      if (e.localFilePath != null) continue;
      candidates.add(e);
    }

    return candidates;
  }

  Future<List<Episode>> _getQueueEpisodesWithoutFile() async {
    final List<Episode> result = <Episode>[];
    final queuedEpisodes = await _db.getQueuedEpisodes();
    for (final qe in queuedEpisodes) {
      if (qe.episode.localFilePath == null) {
        result.add(qe.episode);
      }
    }
    return result;
  }

  Future<String> _resolveDownloadDir() async {
    final Directory appDir = await getApplicationSupportDirectory();
    final Directory downloadDir = Directory('${appDir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<void> _downloadEpisode(Episode episode, String downloadDir) async {
    try {
      final String safeFilename =
          '${episode.guid.replaceAll(RegExp(r'[^\w\-.]'), '_')}.mp3';
      final String filePath = '$downloadDir/$safeFilename';

      // Skip if file already exists on disk (e.g. downloaded by background task)
      if (await File(filePath).exists()) {
        await _db.updateLocalFilePath(episode.guid, filePath);
        return;
      }

      final http.StreamedResponse response = await _client.send(
        http.Request('GET', Uri.parse(episode.audioUrl)),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'OnOpenDownloadService: HTTP ${response.statusCode} for ${episode.audioUrl}',
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
      if (kDebugMode) debugPrint('OnOpenDownloadService: FileSystemException: $e');
    } catch (e) {
      if (kDebugMode) debugPrint('OnOpenDownloadService: download failed: $e');
    }
  }
}
