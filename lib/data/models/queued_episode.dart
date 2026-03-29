import 'episode.dart';

class QueuedEpisode {
  const QueuedEpisode({
    required this.queueId,
    required this.sortOrder,
    required this.episode,
    required this.podcastTitle,
    required this.podcastArtworkUrl,
  });

  final int queueId;
  final int sortOrder;
  final Episode episode;
  final String podcastTitle;
  final String podcastArtworkUrl;

  factory QueuedEpisode.fromMap(Map<String, Object?> map) {
    return QueuedEpisode(
      queueId: map['queue_id'] as int,
      sortOrder: map['queue_sort_order'] as int,
      episode: Episode.fromMap(<String, Object?>{
        'guid': map['guid'],
        'podcast_rss_url': map['podcast_rss_url'],
        'title': map['title'],
        'audio_url': map['audio_url'],
        'description_html': map['description_html'],
        'duration_seconds': map['duration_seconds'],
        'pub_date': map['pub_date'],
        'listened_position_seconds': map['listened_position_seconds'],
        'is_completed': map['is_completed'],
        'local_file_path': map['local_file_path'],
      }),
      podcastTitle: map['podcast_title'] as String,
      podcastArtworkUrl: map['podcast_artwork_url'] as String,
    );
  }
}
