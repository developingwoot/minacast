import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/episode.dart';
import '../../playback/providers/playback_providers.dart';
import '../../playback/models/playback_ui_status.dart';

class EpisodeDetailScreen extends ConsumerWidget {
  const EpisodeDetailScreen({super.key, required this.episode});

  final Episode episode;

  void _showPlaceholderMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    final int remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '${remainingSeconds}s';
  }

  String _formatDate(int milliseconds) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(
      milliseconds,
      isUtc: true,
    ).toLocal();
    const List<String> months = <String>[
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Episode? currentEpisode = ref.watch(currentPlaybackEpisodeProvider);
    final PlaybackUiStatus playbackStatus = ref.watch(playbackStatusProvider);
    final bool isCurrentEpisode = currentEpisode?.guid == episode.guid;
    final bool isLoading =
        isCurrentEpisode && playbackStatus == PlaybackUiStatus.loading;
    final List<String> metadata = <String>[
      if (episode.pubDate > 0) _formatDate(episode.pubDate),
      if (episode.durationSeconds != null)
        _formatDuration(episode.durationSeconds!),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Episode')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(episode.title, style: textTheme.headlineSmall),
            if (metadata.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                metadata.join(' · '),
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(playbackControllerProvider)
                                  .playEpisode(episode);
                            } catch (_) {
                              if (!context.mounted) {
                                return;
                              }
                              _showPlaceholderMessage(
                                context,
                                'We could not start playback right now.',
                              );
                            }
                          },
                    icon: isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(isCurrentEpisode ? 'Play From Here' : 'Play'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPlaceholderMessage(
                      context,
                      'Queue actions are planned for Phase 4.',
                    ),
                    icon: const Icon(Icons.queue_music),
                    label: const Text('Add to Queue'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Show Notes', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            if (episode.descriptionHtml.trim().isEmpty)
              Text(
                'No show notes available.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.outline,
                ),
              )
            else
              Html(data: episode.descriptionHtml),
          ],
        ),
      ),
    );
  }
}
