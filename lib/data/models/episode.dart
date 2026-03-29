class Episode {
  final String guid;
  final String podcastRssUrl;
  final String title;
  final String audioUrl;
  final String descriptionHtml;
  final int? durationSeconds;
  final int pubDate;
  final int listenedPositionSeconds;
  final int isCompleted;
  final String? localFilePath;

  const Episode({
    required this.guid,
    required this.podcastRssUrl,
    required this.title,
    required this.audioUrl,
    required this.descriptionHtml,
    this.durationSeconds,
    required this.pubDate,
    this.listenedPositionSeconds = 0,
    this.isCompleted = 0,
    this.localFilePath,
  });

  factory Episode.fromMap(Map<String, Object?> map) {
    return Episode(
      guid: map['guid'] as String,
      podcastRssUrl: map['podcast_rss_url'] as String,
      title: map['title'] as String,
      audioUrl: map['audio_url'] as String,
      descriptionHtml: map['description_html'] as String,
      durationSeconds: map['duration_seconds'] as int?,
      pubDate: map['pub_date'] as int,
      listenedPositionSeconds: map['listened_position_seconds'] as int,
      isCompleted: map['is_completed'] as int,
      localFilePath: map['local_file_path'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'guid': guid,
      'podcast_rss_url': podcastRssUrl,
      'title': title,
      'audio_url': audioUrl,
      'description_html': descriptionHtml,
      'duration_seconds': durationSeconds,
      'pub_date': pubDate,
      'listened_position_seconds': listenedPositionSeconds,
      'is_completed': isCompleted,
      'local_file_path': localFilePath,
    };
  }
}
