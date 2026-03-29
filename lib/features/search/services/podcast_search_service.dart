import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../data/models/podcast.dart';

class PodcastSearchService {
  final http.Client _client;

  PodcastSearchService({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<Podcast>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final Uri uri = Uri.https('itunes.apple.com', '/search', {
      'term': query.trim(),
      'media': 'podcast',
      'limit': '20',
    });

    try {
      final http.Response response = await _client.get(uri);
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('PodcastSearchService: HTTP ${response.statusCode}');
        }
        return [];
      }

      final Map<String, dynamic> body =
          json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> results = body['results'] as List<dynamic>? ?? [];

      final List<Podcast> podcasts = [];
      for (final dynamic item in results) {
        final Map<String, dynamic> map = item as Map<String, dynamic>;
        final String? feedUrl = map['feedUrl'] as String?;
        if (feedUrl == null || feedUrl.isEmpty) continue;

        final String rawTitle = map['collectionName'] as String? ?? '';
        final String rawAuthor = map['artistName'] as String? ?? '';
        final String artworkUrl =
            map['artworkUrl600'] as String? ??
            map['artworkUrl100'] as String? ??
            '';

        podcasts.add(
          Podcast(
            rssUrl: feedUrl,
            title: rawTitle.isEmpty
                ? 'Unknown Podcast'
                : _truncate(rawTitle, 500),
            author: _truncate(rawAuthor, 500),
            description: '',
            artworkUrl: artworkUrl,
            lastCheckedAt: 0,
          ),
        );
      }
      return podcasts;
    } catch (e) {
      if (kDebugMode) debugPrint('PodcastSearchService.search failed: $e');
      return [];
    }
  }

  String _truncate(String s, int maxLen) =>
      s.length > maxLen ? s.substring(0, maxLen) : s;
}
