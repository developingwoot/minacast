import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:minacast/data/models/episode.dart';
import 'package:minacast/features/episode_detail/screens/episode_detail_screen.dart';

void main() {
  testWidgets('episode detail renders metadata and show notes', (
    WidgetTester tester,
  ) async {
    const Episode episode = Episode(
      guid: 'episode-1',
      podcastRssUrl: 'https://example.com/feed.xml',
      title: 'Episode One',
      audioUrl: 'https://example.com/episode-1.mp3',
      descriptionHtml: '<p>Hello <strong>world</strong></p>',
      durationSeconds: 1950,
      pubDate: 1648468800000,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EpisodeDetailScreen(episode: episode)),
      ),
    );
    await tester.pump();

    expect(find.text('Episode One'), findsOneWidget);
    expect(find.text('Mar 28, 2022 · 32m'), findsOneWidget);
    expect(find.text('Show Notes'), findsOneWidget);
    expect(find.text('Hello world'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Add to Queue'), findsOneWidget);
  });
}
