import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../episode_detail/screens/episode_detail_screen.dart';
import '../models/playback_progress.dart';
import '../models/playback_ui_status.dart';
import '../models/sleep_timer_state.dart';
import '../providers/playback_providers.dart';
import '../../settings/providers/settings_providers.dart';

class FullPlayerScreen extends ConsumerStatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen> {
  double? _dragValue;

  String _formatClock(Duration duration) {
    final int totalSeconds = duration.inSeconds;
    final int minutes = (totalSeconds ~/ 60) % 60;
    final int seconds = totalSeconds % 60;
    final int hours = totalSeconds ~/ 3600;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSleepTimerLabel(SleepTimerState state, int defaultMinutes) {
    if (!state.isActive || state.remaining == null) {
      return 'Start Sleep Timer ($defaultMinutes min)';
    }

    final int totalSeconds = state.remaining!.inSeconds;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return 'Cancel Sleep Timer ($minutes:${seconds.toString().padLeft(2, '0')})';
  }

  @override
  Widget build(BuildContext context) {
    final episode = ref.watch(currentPlaybackEpisodeProvider);
    final mediaItem = ref.watch(
      playbackStateProvider.select((value) => value.currentMediaItem),
    );
    final PlaybackUiStatus status = ref.watch(playbackStatusProvider);
    final PlaybackProgress progress = ref.watch(playbackProgressProvider);
    final double speed = ref.watch(playbackSpeedProvider);
    final SleepTimerState sleepTimerState = ref.watch(sleepTimerStateProvider);
    final int sleepTimerDefaultMinutes = ref.watch(
      sleepTimerDefaultMinutesProvider,
    );

    if (episode == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Player')),
        body: const Center(child: Text('No episode is currently loaded.')),
      );
    }

    final double durationSeconds = progress.duration.inSeconds.toDouble();
    final double sliderMax = durationSeconds > 0 ? durationSeconds : 1;
    final double sliderValue =
        _dragValue ??
        progress.position.inSeconds.clamp(0, sliderMax).toDouble();
    final bool isPlaying = status == PlaybackUiStatus.playing;

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          _PlayerArtwork(imageUrl: mediaItem?.artUri?.toString()),
          const SizedBox(height: 24),
          Text(
            episode.title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          if (mediaItem?.album?.isNotEmpty == true) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              mediaItem!.album!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          Slider(
            value: sliderValue.clamp(0, sliderMax),
            max: sliderMax,
            onChanged: (double value) {
              setState(() {
                _dragValue = value;
              });
            },
            onChangeEnd: (double value) async {
              setState(() {
                _dragValue = null;
              });
              await ref
                  .read(playbackControllerProvider)
                  .seek(Duration(seconds: value.round()));
            },
          ),
          Row(
            children: <Widget>[
              Text(_formatClock(progress.position)),
              const Spacer(),
              Text(
                _formatClock(
                  progress.duration > progress.position
                      ? progress.duration - progress.position
                      : Duration.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              IconButton(
                tooltip: 'Skip back 30 seconds',
                onPressed: () =>
                    ref.read(playbackControllerProvider).skipBackward30(),
                iconSize: 40,
                icon: const Icon(Icons.replay_30),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: () =>
                    ref.read(playbackControllerProvider).togglePlayPause(),
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                label: Text(isPlaying ? 'Pause' : 'Play'),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Skip forward 30 seconds',
                onPressed: () =>
                    ref.read(playbackControllerProvider).skipForward30(),
                iconSize: 40,
                icon: const Icon(Icons.forward_30),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <double>[0.5, 1.0, 1.5, 2.0].map((double option) {
              final bool selected = speed == option;
              return ChoiceChip(
                label: Text('${option.toStringAsFixed(1)}x'),
                selected: selected,
                onSelected: (_) => ref
                    .read(playbackControllerProvider)
                    .setPlaybackSpeed(option),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () async {
              if (sleepTimerState.isActive) {
                await ref.read(playbackControllerProvider).cancelSleepTimer();
                return;
              }

              final int defaultMinutes = await ref
                  .read(playbackControllerProvider)
                  .loadSleepTimerDefaultMinutes();
              await ref
                  .read(playbackControllerProvider)
                  .startSleepTimer(Duration(minutes: defaultMinutes));
            },
            icon: Icon(
              sleepTimerState.isActive ? Icons.timer_off : Icons.timer,
            ),
            label: Text(
              _formatSleepTimerLabel(sleepTimerState, sleepTimerDefaultMinutes),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    EpisodeDetailScreen(episode: episode),
              ),
            ),
            icon: const Icon(Icons.notes),
            label: const Text('Open Show Notes'),
          ),
        ],
      ),
    );
  }
}

class _PlayerArtwork extends StatelessWidget {
  const _PlayerArtwork({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (imageUrl == null || imageUrl!.isEmpty) {
      return _ArtworkPlaceholder(colorScheme: colorScheme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: double.infinity,
        height: 280,
        fit: BoxFit.cover,
        placeholder: (BuildContext context, String url) =>
            _ArtworkPlaceholder(colorScheme: colorScheme),
        errorWidget: (BuildContext context, String url, Object error) =>
            _ArtworkPlaceholder(colorScheme: colorScheme),
      ),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surfaceContainerHighest,
      ),
      child: const Center(child: Icon(Icons.podcasts, size: 72)),
    );
  }
}
