import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minacast/data/database_helper.dart';
import 'package:minacast/data/models/episode.dart';
import 'package:minacast/data/models/podcast.dart';
import 'package:minacast/features/home/providers/feed_provider.dart';
import 'package:minacast/features/podcast_detail/providers/podcast_detail_provider.dart';
import 'package:minacast/features/podcast_detail/services/rss_feed_service.dart';
import 'package:minacast/features/search/providers/search_provider.dart';
import 'package:minacast/features/search/services/podcast_search_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.useInMemoryDatabaseForTests();
  });

  setUp(() async {
    await DatabaseHelper.instance.resetForTest();
  });

  test('searchProvider returns podcasts after debounce', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        searchDebounceDurationProvider.overrideWith((Ref ref) => Duration.zero),
        podcastSearchServiceProvider.overrideWith(
          (Ref ref) => PodcastSearchService(
            client: MockClient((http.Request request) async {
              return http.Response('''
              {
                "results": [
                  {
                    "feedUrl": "https://example.com/feed.xml",
                    "collectionName": "Riverpod Show",
                    "artistName": "Host",
                    "artworkUrl600": "https://example.com/art.jpg"
                  }
                ]
              }
              ''', 200);
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(searchProvider.notifier).search('riverpod');
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final List<Podcast> results = await container.read(searchProvider.future);
    expect(results, hasLength(1));
    expect(results.first.title, 'Riverpod Show');
  });

  test(
    'podcastDetailProvider loads feed and subscribe writes to sqlite',
    () async {
      final ProviderContainer container = ProviderContainer(
        overrides: [
          rssFeedServiceProvider.overrideWith(
            (Ref ref) => RssFeedService(
              client: MockClient((http.Request request) async {
                return http.Response('''
              <rss version="2.0">
                <channel>
                  <description>Detail description</description>
                  <item>
                    <guid>episode-1</guid>
                    <title>Episode One</title>
                    <description><![CDATA[<p>hello</p>]]></description>
                    <pubDate>2024-01-01T00:00:00Z</pubDate>
                    <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg" />
                  </item>
                </channel>
              </rss>
              ''', 200);
              }),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final Podcast podcast = Podcast(
        rssUrl: 'https://example.com/feed.xml',
        title: 'Example',
        author: 'Host',
        description: '',
        artworkUrl: 'https://example.com/art.jpg',
        lastCheckedAt: 0,
      );

      final PodcastDetailState detailState = await container.read(
        podcastDetailProvider(podcast.rssUrl).future,
      );
      expect(detailState.isSubscribed, isFalse);
      expect(detailState.description, 'Detail description');
      expect(detailState.episodes, hasLength(1));

      await container
          .read(podcastDetailProvider(podcast.rssUrl).notifier)
          .subscribe(podcast);

      final Podcast? storedPodcast = await DatabaseHelper.instance
          .getPodcastByUrl(podcast.rssUrl);
      final Episode? storedEpisode = await DatabaseHelper.instance
          .getEpisodeByGuid('episode-1');

      expect(storedPodcast, isNotNull);
      expect(storedPodcast!.description, 'Detail description');
      expect(storedEpisode, isNotNull);
    },
  );

  test('feedProvider returns episodes newest first', () async {
    await DatabaseHelper.instance.insertPodcast(
      const Podcast(
        rssUrl: 'https://example.com/feed.xml',
        title: 'Example',
        author: 'Host',
        description: 'Desc',
        artworkUrl: 'https://example.com/art.jpg',
        lastCheckedAt: 1,
      ),
    );
    await DatabaseHelper.instance.insertEpisode(
      const Episode(
        guid: 'older',
        podcastRssUrl: 'https://example.com/feed.xml',
        title: 'Older Episode',
        audioUrl: 'https://example.com/older.mp3',
        descriptionHtml: '<p>older</p>',
        pubDate: 100,
      ),
    );
    await DatabaseHelper.instance.insertEpisode(
      const Episode(
        guid: 'newer',
        podcastRssUrl: 'https://example.com/feed.xml',
        title: 'Newer Episode',
        audioUrl: 'https://example.com/newer.mp3',
        descriptionHtml: '<p>newer</p>',
        pubDate: 200,
      ),
    );

    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);

    final List<Episode> episodes = await container.read(feedProvider.future);
    expect(episodes, hasLength(2));
    expect(episodes.first.guid, 'newer');
    expect(episodes.last.guid, 'older');
  });
}
