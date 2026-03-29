import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/queued_episode.dart';
import '../../episode_detail/screens/episode_detail_screen.dart';
import '../providers/queue_providers.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<QueuedEpisode>> queueState = ref.watch(queueProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Queue')),
      body: queueState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'We could not load your queue right now. Please try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (List<QueuedEpisode> queuedEpisodes) {
          if (queuedEpisodes.isEmpty) {
            return const _QueueEmptyState();
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: queuedEpisodes.length,
            onReorder: (int oldIndex, int newIndex) async {
              try {
                await ref
                    .read(queueProvider.notifier)
                    .reorderQueue(oldIndex, newIndex);
              } catch (_) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'We could not update the queue order right now.',
                    ),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context, int index) {
              final QueuedEpisode queuedEpisode = queuedEpisodes[index];
              return _QueuedEpisodeTile(queuedEpisode: queuedEpisode);
            },
          );
        },
      ),
    );
  }
}

class _QueueEmptyState extends StatelessWidget {
  const _QueueEmptyState();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.queue_music, size: 72, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Your queue is empty.',
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add episodes from Episode Detail to line up what plays next.',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuedEpisodeTile extends ConsumerWidget {
  const _QueuedEpisodeTile({required this.queuedEpisode});

  final QueuedEpisode queuedEpisode;

  String _formatDuration(int seconds) {
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    if (minutes > 0) {
      return '${minutes}m';
    }
    return '${seconds}s';
  }

  Future<bool?> _handleDismiss(
    BuildContext context,
    WidgetRef ref,
    DismissDirection direction,
  ) async {
    try {
      await ref
          .read(queueProvider.notifier)
          .removeQueuedEpisode(queuedEpisode.queueId);
      return true;
    } catch (_) {
      if (!context.mounted) {
        return false;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('We could not remove that episode from the queue.'),
        ),
      );
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String subtitle = [
      queuedEpisode.podcastTitle,
      if (queuedEpisode.episode.durationSeconds != null)
        _formatDuration(queuedEpisode.episode.durationSeconds!),
    ].join(' · ');

    return Dismissible(
      key: ValueKey<int>(queuedEpisode.queueId),
      direction: DismissDirection.endToStart,
      confirmDismiss: (DismissDirection direction) =>
          _handleDismiss(context, ref, direction),
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          key: ValueKey<String>('queue-tile-${queuedEpisode.queueId}'),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: queuedEpisode.podcastArtworkUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorWidget: (BuildContext context, String url, Object error) =>
                  Container(
                    width: 52,
                    height: 52,
                    color: colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(Icons.podcasts, color: colorScheme.outline),
                  ),
            ),
          ),
          title: Text(
            queuedEpisode.episode.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          trailing: ReorderableDragStartListener(
            index: queuedEpisode.sortOrder,
            child: Icon(Icons.drag_handle, color: colorScheme.outline),
          ),
          onTap: () {
            unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      EpisodeDetailScreen(episode: queuedEpisode.episode),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
