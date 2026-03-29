import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:minacast/features/podcast_detail/services/rss_feed_service.dart';

void main() {
  group('RssFeedService', () {
    test('parses feed description and valid episodes', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('''
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Example Podcast</title>
            <description>Feed description</description>
            <item>
              <guid>episode-1</guid>
              <title>Episode One</title>
              <description><![CDATA[<p>Hello</p>]]></description>
              <pubDate>Mon, 28 Mar 2022 12:00:00 +0000</pubDate>
              <itunes:duration>32:30</itunes:duration>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg" />
            </item>
          </channel>
        </rss>
        ''', 200);
      });

      final RssFeedService service = RssFeedService(client: client);
      final PodcastFeedData feedData = await service.fetchFeed(
        'https://example.com/feed.xml',
      );

      expect(feedData.description, 'Feed description');
      expect(feedData.episodes, hasLength(1));
      expect(feedData.episodes.first.guid, 'episode-1');
      expect(feedData.episodes.first.title, 'Episode One');
      expect(feedData.episodes.first.durationSeconds, 1950);
      expect(feedData.episodes.first.pubDate, greaterThan(0));
    });

    test('skips items missing guid or enclosure', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('''
        <rss version="2.0">
          <channel>
            <description>Feed description</description>
            <item>
              <title>No enclosure</title>
              <guid>episode-1</guid>
            </item>
            <item>
              <title>No guid</title>
              <enclosure url="https://example.com/ep2.mp3" type="audio/mpeg" />
            </item>
          </channel>
        </rss>
        ''', 200);
      });

      final RssFeedService service = RssFeedService(client: client);
      final PodcastFeedData feedData = await service.fetchFeed(
        'https://example.com/feed.xml',
      );

      expect(feedData.episodes, isEmpty);
    });

    test('returns empty feed on malformed xml', () async {
      final MockClient client = MockClient((http.Request request) async {
        return http.Response('<rss><channel>', 200);
      });

      final RssFeedService service = RssFeedService(client: client);
      final PodcastFeedData feedData = await service.fetchFeed(
        'https://example.com/feed.xml',
      );

      expect(feedData.description, isEmpty);
      expect(feedData.episodes, isEmpty);
    });
  });
}
