import 'package:audio_service/audio_service.dart';

import '../../../data/models/episode.dart';
import '../../../data/models/podcast.dart';

const String _guidKey = 'guid';
const String _podcastRssUrlKey = 'podcastRssUrl';
const String _audioUrlKey = 'audioUrl';
const String _descriptionHtmlKey = 'descriptionHtml';
const String _durationSecondsKey = 'durationSeconds';
const String _pubDateKey = 'pubDate';
const String _localFilePathKey = 'localFilePath';

MediaItem mediaItemFromEpisode(Episode episode, {Podcast? podcast}) {
  return MediaItem(
    id: episode.guid,
    album: podcast?.title,
    title: episode.title,
    artist: podcast?.author,
    duration: episode.durationSeconds == null
        ? null
        : Duration(seconds: episode.durationSeconds!),
    artUri: podcast?.artworkUrl.isNotEmpty == true
        ? Uri.tryParse(podcast!.artworkUrl)
        : null,
    extras: <String, Object?>{
      _guidKey: episode.guid,
      _podcastRssUrlKey: episode.podcastRssUrl,
      _audioUrlKey: episode.audioUrl,
      _descriptionHtmlKey: episode.descriptionHtml,
      _durationSecondsKey: episode.durationSeconds,
      _pubDateKey: episode.pubDate,
      _localFilePathKey: episode.localFilePath,
    },
  );
}

Episode episodeFromMediaItem(MediaItem mediaItem) {
  final Map<String, dynamic> extras = mediaItem.extras ?? <String, dynamic>{};

  return Episode(
    guid: extras[_guidKey] as String? ?? mediaItem.id,
    podcastRssUrl: extras[_podcastRssUrlKey] as String? ?? '',
    title: mediaItem.title,
    audioUrl: extras[_audioUrlKey] as String? ?? '',
    descriptionHtml: extras[_descriptionHtmlKey] as String? ?? '',
    durationSeconds: extras[_durationSecondsKey] as int?,
    pubDate: extras[_pubDateKey] as int? ?? 0,
    localFilePath: extras[_localFilePathKey] as String?,
  );
}
