import 'package:dart_rss/dart_rss.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../data/models/episode.dart';

class PodcastFeedData {
  const PodcastFeedData({required this.description, required this.episodes});

  final String description;
  final List<Episode> episodes;
}

class RssFeedService {
  RssFeedService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<PodcastFeedData> fetchFeed(String rssUrl) async {
    try {
      final http.Response response = await _client.get(Uri.parse(rssUrl));
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('RssFeedService: HTTP ${response.statusCode} for $rssUrl');
        }
        return const PodcastFeedData(description: '', episodes: <Episode>[]);
      }

      final RssFeed feed = RssFeed.parse(response.body);
      final List<Episode> episodes = <Episode>[];

      for (final RssItem item in feed.items) {
        final String? guid = item.guid ?? item.link;
        final String? audioUrl = item.enclosure?.url;
        if (guid == null || guid.isEmpty) {
          continue;
        }
        if (audioUrl == null || audioUrl.isEmpty) {
          continue;
        }

        final String title = _truncate(item.title ?? 'Untitled', 500);
        final String descriptionHtml = _truncate(
          item.content?.value ?? item.description ?? '',
          50000,
        );
        final int? durationSeconds = item.itunes?.duration?.inSeconds;
        final int pubDate = _parsePubDate(item.pubDate);

        episodes.add(
          Episode(
            guid: _truncate(guid, 500),
            podcastRssUrl: rssUrl,
            title: title,
            audioUrl: _truncate(audioUrl, 2000),
            descriptionHtml: descriptionHtml,
            durationSeconds: durationSeconds,
            pubDate: pubDate,
          ),
        );
      }

      final String description = _truncate(
        feed.itunes?.summary ?? feed.description ?? '',
        50000,
      );

      return PodcastFeedData(description: description, episodes: episodes);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('RssFeedService.fetchFeed failed: $error');
      }
      return const PodcastFeedData(description: '', episodes: <Episode>[]);
    }
  }

  String _truncate(String value, int maxLength) {
    return value.length > maxLength ? value.substring(0, maxLength) : value;
  }

  int _parsePubDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return 0;
    }

    final DateTime? isoDate = DateTime.tryParse(dateStr);
    if (isoDate != null) {
      return isoDate.millisecondsSinceEpoch;
    }

    try {
      final String normalized = dateStr.trim().replaceFirst(
        RegExp(r'^\w{3},\s*'),
        '',
      );
      final List<String> parts = normalized.split(RegExp(r'\s+'));
      if (parts.length < 4) {
        return 0;
      }

      final int day = int.parse(parts[0]);
      final int? month = _months[parts[1].toLowerCase()];
      final int year = int.parse(parts[2]);
      final List<String> timeParts = parts[3].split(':');
      final int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final int second = timeParts.length > 2 ? int.parse(timeParts[2]) : 0;

      if (month == null) {
        return 0;
      }

      return DateTime.utc(
        year,
        month,
        day,
        hour,
        minute,
        second,
      ).millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  static const Map<String, int> _months = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };
}
