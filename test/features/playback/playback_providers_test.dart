import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:minacast/data/models/episode.dart';
import 'package:minacast/features/playback/models/playback_progress.dart';
import 'package:minacast/features/playback/models/playback_ui_status.dart';
import 'package:minacast/features/playback/providers/playback_providers.dart';

import 'fake_playback_controller.dart';

void main() {
  test('playback providers expose current episode and mini player visibility', () async {
    final FakePlaybackController fakeController = FakePlaybackController();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        audioHandlerProvider.overrideWithValue(fakeController),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await fakeController.dispose();
    });

    expect(container.read(miniPlayerVisibleProvider), isFalse);

    const Episode episode = Episode(
      guid: 'episode-1',
      podcastRssUrl: 'https://example.com/feed.xml',
      title: 'Provider Test Episode',
      audioUrl: 'https://example.com/episode.mp3',
      descriptionHtml: '<p>notes</p>',
      pubDate: 100,
    );

    fakeController.emitEpisode(episode);
    fakeController.emitMediaItem(
      const MediaItem(id: 'episode-1', title: 'Provider Test Episode'),
    );
    fakeController.emitStatus(PlaybackUiStatus.playing);
    fakeController.emitProgress(
      const PlaybackProgress(
        position: Duration(seconds: 12),
        duration: Duration(seconds: 120),
      ),
    );

    await Future<void>.delayed(Duration.zero);

    expect(container.read(currentPlaybackEpisodeProvider)?.guid, 'episode-1');
    expect(container.read(playbackStatusProvider), PlaybackUiStatus.playing);
    expect(container.read(playbackProgressProvider).position.inSeconds, 12);
    expect(container.read(miniPlayerVisibleProvider), isTrue);
  });
}
