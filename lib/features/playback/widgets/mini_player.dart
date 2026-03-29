import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/playback_ui_status.dart';
import '../providers/playback_providers.dart';
import '../screens/full_player_screen.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final episode = ref.watch(currentPlaybackEpisodeProvider);
    final mediaItem = ref.watch(
      playbackStateProvider.select((value) => value.currentMediaItem),
    );
    final PlaybackUiStatus status = ref.watch(playbackStatusProvider);

    if (episode == null) {
      return const SizedBox.shrink();
    }

    final bool isPlaying = status == PlaybackUiStatus.playing;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const FullPlayerScreen(),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: <Widget>[
                _MiniPlayerArtwork(imageUrl: mediaItem?.artUri?.toString()),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    episode.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: isPlaying ? 'Pause' : 'Play',
                  onPressed: () => ref
                      .read(playbackControllerProvider)
                      .togglePlayPause(),
                  icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                ),
                IconButton(
                  tooltip: 'Skip forward 30 seconds',
                  onPressed: () => ref
                      .read(playbackControllerProvider)
                      .skipForward30(),
                  icon: const Icon(Icons.forward_30),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayerArtwork extends StatelessWidget {
  const _MiniPlayerArtwork({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (imageUrl == null || imageUrl!.isEmpty) {
      return _ArtworkFallback(colorScheme: colorScheme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        placeholder: (BuildContext context, String url) =>
            _ArtworkFallback(colorScheme: colorScheme),
        errorWidget: (BuildContext context, String url, Object error) =>
            _ArtworkFallback(colorScheme: colorScheme),
      ),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.podcasts),
    );
  }
}
