class Podcast {
  final String rssUrl;
  final String title;
  final String author;
  final String description;
  final String artworkUrl;
  final int lastCheckedAt;

  const Podcast({
    required this.rssUrl,
    required this.title,
    required this.author,
    required this.description,
    required this.artworkUrl,
    required this.lastCheckedAt,
  });

  factory Podcast.fromMap(Map<String, Object?> map) {
    return Podcast(
      rssUrl: map['rss_url'] as String,
      title: map['title'] as String,
      author: map['author'] as String,
      description: map['description'] as String,
      artworkUrl: map['artwork_url'] as String,
      lastCheckedAt: map['last_checked_at'] as int,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'rss_url': rssUrl,
      'title': title,
      'author': author,
      'description': description,
      'artwork_url': artworkUrl,
      'last_checked_at': lastCheckedAt,
    };
  }
}
