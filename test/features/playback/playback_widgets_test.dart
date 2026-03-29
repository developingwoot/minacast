import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:minacast/data/models/episode.dart';
import 'package:minacast/features/playback/models/playback_progress.dart';
import 'package:minacast/features/playback/models/playback_ui_status.dart';
import 'package:minacast/features/playback/providers/playback_providers.dart';
import 'package:minacast/features/playback/screens/full_player_screen.dart';
import 'package:minacast/features/playback/widgets/mini_player.dart';
import 'package:minacast/features/settings/providers/settings_providers.dart';

import 'fake_playback_controller.dart';

void main() {
  Widget buildTestApp(
    FakePlaybackController fakeController,
    Widget child, {
    int sleepTimerDefaultMinutes = 30,
  }) {
    return ProviderScope(
      overrides: [
        audioHandlerProvider.overrideWithValue(fakeController),
        sleepTimerDefaultMinutesProvider.overrideWith(
          (Ref ref) => sleepTimerDefaultMinutes,
        ),
      ],
      child: MaterialApp(home: child),
    );
  }

  Episode buildEpisode() {
    return const Episode(
      guid: 'episode-1',
      podcastRssUrl: 'https://example.com/feed.xml',
      title: 'Widget Test Episode',
      audioUrl: 'https://example.com/episode.mp3',
      descriptionHtml: '<p>notes</p>',
      durationSeconds: 180,
      pubDate: 100,
    );
  }

  setUp(() {});

  testWidgets('mini player opens full player screen', (
    WidgetTester tester,
  ) async {
    final FakePlaybackController fakeController = FakePlaybackController();
    final Episode episode = buildEpisode();
    fakeController.emitEpisode(episode);
    fakeController.emitMediaItem(
      const MediaItem(id: 'episode-1', title: 'Widget Test Episode'),
    );
    fakeController.emitStatus(PlaybackUiStatus.playing);

    addTearDown(fakeController.dispose);

    await tester.pumpWidget(
      buildTestApp(fakeController, const Scaffold(body: MiniPlayer())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Widget Test Episode'), findsOneWidget);

    await tester.tap(find.text('Widget Test Episode'));
    await tester.pumpAndSettle();

    expect(find.byType(FullPlayerScreen), findsOneWidget);
  });

  testWidgets('full player controls dispatch playback commands', (
    WidgetTester tester,
  ) async {
    final FakePlaybackController fakeController = FakePlaybackController();
    final Episode episode = buildEpisode();
    fakeController.emitEpisode(episode);
    fakeController.emitMediaItem(
      const MediaItem(
        id: 'episode-1',
        title: 'Widget Test Episode',
        album: 'Widget Podcast',
      ),
    );
    fakeController.emitStatus(PlaybackUiStatus.paused);
    fakeController.emitProgress(
      const PlaybackProgress(
        position: Duration(seconds: 30),
        duration: Duration(seconds: 180),
      ),
    );

    addTearDown(fakeController.dispose);

    await tester.pumpWidget(
      buildTestApp(
        fakeController,
        const FullPlayerScreen(),
        sleepTimerDefaultMinutes: 45,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();
    expect(fakeController.togglePlayPauseCalls, 1);

    await tester.tap(find.byIcon(Icons.forward_30));
    await tester.pumpAndSettle();
    expect(fakeController.skipForwardCalls, 1);

    await tester.scrollUntilVisible(
      find.text('Start Sleep Timer (45 min)'),
      250,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Start Sleep Timer (45 min)'), findsOneWidget);
  });
}
