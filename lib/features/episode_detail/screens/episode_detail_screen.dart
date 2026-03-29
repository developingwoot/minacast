import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../data/models/episode.dart';

class EpisodeDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
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
                    onPressed: () => _showPlaceholderMessage(
                      context,
                      'Playback will be connected in Session 3.2.',
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play'),
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
