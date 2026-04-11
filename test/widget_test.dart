import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minacast/data/database_helper.dart';
import 'package:minacast/data/models/episode.dart';
import 'package:minacast/features/episode_detail/screens/episode_detail_screen.dart';
import 'package:minacast/features/home/providers/feed_provider.dart';
import 'package:minacast/features/home/screens/home_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.useInMemoryDatabaseForTests();
  });

  setUp(() async {
    await DatabaseHelper.instance.resetForTest();
  });

  Widget buildTestApp(List<Episode> episodes) {
    return ProviderScope(
      overrides: [feedProvider.overrideWith((Ref ref) async => episodes)],
      child: const MaterialApp(home: HomeScreen()),
    );
  }

  testWidgets('home shows empty state when there are no subscriptions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const <Episode>[]));
    await tester.pump();

    expect(find.text('Your feed is empty.'), findsOneWidget);
    expect(
      find.text('Go to the Podcasts tab to search for shows and subscribe.'),
      findsOneWidget,
    );
  });

  testWidgets('home screen has no search icon (search moved to Podcasts tab)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp(const <Episode>[]));
    await tester.pump();

    expect(find.byTooltip('Search podcasts'), findsNothing);
  });

  testWidgets('home feed shows seeded episodes newest first', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(const <Episode>[
        Episode(
          guid: 'episode-2',
          podcastRssUrl: 'https://example.com/feed.xml',
          title: 'Newer Episode',
          audioUrl: 'https://example.com/newer.mp3',
          descriptionHtml: '<p>Newer</p>',
          pubDate: 200,
        ),
        Episode(
          guid: 'episode-1',
          podcastRssUrl: 'https://example.com/feed.xml',
          title: 'Older Episode',
          audioUrl: 'https://example.com/older.mp3',
          descriptionHtml: '<p>Older</p>',
          pubDate: 100,
        ),
      ]),
    );
    await tester.pump();

    expect(find.text('Newer Episode'), findsOneWidget);
    expect(find.text('Older Episode'), findsOneWidget);

    final Finder listTileFinder = find.byType(ListTile);
    final List<ListTile> tiles = tester
        .widgetList<ListTile>(listTileFinder)
        .toList();
    expect((tiles.first.title as Text).data, 'Newer Episode');
    expect((tiles.last.title as Text).data, 'Older Episode');
  });

  testWidgets('tapping a home episode opens episode detail', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(const <Episode>[
        Episode(
          guid: 'episode-1',
          podcastRssUrl: 'https://example.com/feed.xml',
          title: 'Episode Detail Test',
          audioUrl: 'https://example.com/episode.mp3',
          descriptionHtml: '<p>Show notes</p>',
          durationSeconds: 120,
          pubDate: 100,
        ),
      ]),
    );
    await tester.pump();

    await tester.tap(find.text('Episode Detail Test'));
    await tester.pumpAndSettle();

    expect(find.byType(EpisodeDetailScreen), findsOneWidget);
    expect(find.text('Show Notes'), findsOneWidget);
  });
}
