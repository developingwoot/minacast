import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:minacast/features/search/services/podcast_search_service.dart';

void main() {
  group('PodcastSearchService', () {
    test('returns parsed podcasts for a successful response', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('''
        {
          "results": [
            {
              "feedUrl": "https://example.com/feed.xml",
              "collectionName": "Example Show",
              "artistName": "Example Author",
              "artworkUrl600": "https://example.com/art.jpg"
            }
          ]
        }
        ''', 200);
      });

      final PodcastSearchService service = PodcastSearchService(client: client);
      final results = await service.search('example');

      expect(results, hasLength(1));
      expect(results.first.rssUrl, 'https://example.com/feed.xml');
      expect(results.first.title, 'Example Show');
      expect(results.first.author, 'Example Author');
      expect(results.first.artworkUrl, 'https://example.com/art.jpg');
    });

    test('returns empty list on a non-200 response', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('oops', 500);
      });

      final PodcastSearchService service = PodcastSearchService(client: client);
      final results = await service.search('example');

      expect(results, isEmpty);
    });

    test('returns empty list for malformed json', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('{bad json}', 200);
      });

      final PodcastSearchService service = PodcastSearchService(client: client);
      final results = await service.search('example');

      expect(results, isEmpty);
    });
  });
}
