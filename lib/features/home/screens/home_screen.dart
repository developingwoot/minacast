import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../data/models/episode.dart';
import '../../../data/providers/database_provider.dart';
import '../../episode_detail/screens/episode_detail_screen.dart';
import '../../playback/providers/playback_providers.dart';
import '../../podcast_detail/widgets/episode_list_item.dart';
import '../../queue/providers/queue_providers.dart';
import '../../queue/screens/queue_screen.dart';
import '../../search/screens/search_screen.dart';
import '../providers/downloading_episodes_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/feed_sort_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _openSearch(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SearchScreen(),
      ),
    );
  }

  Future<void> _openEpisodeDetail(BuildContext context, Episode episode) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            EpisodeDetailScreen(episode: episode),
      ),
    );
  }

  Future<void> _openQueue(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const QueueScreen(),
      ),
    );
  }

  Future<void> _refreshFeed(WidgetRef ref) async {
    ref.invalidate(feedProvider);
    await ref.read(feedProvider.future);
  }

  Future<void> _markAsPlayed(
    BuildContext context,
    WidgetRef ref,
    Episode episode,
  ) async {
    await ref.read(databaseHelperProvider).markEpisodeCompleted(episode.guid);
    ref.invalidate(feedProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Marked as played'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await ref
                .read(databaseHelperProvider)
                .unmarkEpisodeCompleted(episode.guid);
            ref.invalidate(feedProvider);
          },
        ),
      ),
    );
  }

  Future<void> _showDownloadMenu(
    BuildContext context,
    WidgetRef ref,
    Episode episode,
  ) async {
    final bool isDownloaded = episode.localFilePath != null;
    final bool isDownloading =
        ref.read(downloadingEpisodesProvider).contains(episode.guid);

    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: Icon(
                  isDownloaded
                      ? Icons.offline_pin_outlined
                      : isDownloading
                      ? Icons.downloading_outlined
                      : Icons.download_outlined,
                ),
                title: Text(
                  isDownloaded
                      ? 'Already downloaded'
                      : isDownloading
                      ? 'Downloading…'
                      : 'Download episode',
                ),
                enabled: !isDownloaded && !isDownloading,
                onTap: isDownloaded || isDownloading
                    ? null
                    : () {
                        Navigator.of(ctx).pop();
                        _downloadEpisode(context, ref, episode);
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadEpisode(
    BuildContext context,
    WidgetRef ref,
    Episode episode,
  ) async {
    // Check WiFi before starting
    final List<ConnectivityResult> results =
        await Connectivity().checkConnectivity();
    if (!results.contains(ConnectivityResult.wifi)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to WiFi to download episodes.'),
        ),
      );
      return;
    }

    // Mark as downloading
    ref.read(downloadingEpisodesProvider.notifier).add(episode.guid);

    try {
      final Directory appDir = await getApplicationSupportDirectory();
      final Directory downloadDir = Directory('${appDir.path}/downloads');
      if (!await downloadDir.exists()) await downloadDir.create(recursive: true);

      final String safeFilename =
          '${episode.guid.replaceAll(RegExp(r'[^\w\-.]'), '_')}.mp3';
      final String filePath = '${downloadDir.path}/$safeFilename';

      final http.Client client = http.Client();
      try {
        final http.StreamedResponse response = await client.send(
          http.Request('GET', Uri.parse(episode.audioUrl)),
        );

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }

        final File file = File(filePath);
        final IOSink sink = file.openWrite();
        try {
          await response.stream.pipe(sink);
        } finally {
          await sink.close();
        }
      } finally {
        client.close();
      }

      await ref.read(databaseHelperProvider).updateLocalFilePath(
        episode.guid,
        filePath,
      );
      ref.invalidate(feedProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download failed. Please try again.')),
        );
      }
    } finally {
      ref.read(downloadingEpisodesProvider.notifier).remove(episode.guid);
    }
  }

  void _toggleSort(WidgetRef ref) {
    ref.read(feedSortProvider.notifier).toggle();
  }

  Future<void> _playAll(
    BuildContext context,
    WidgetRef ref,
    List<Episode> episodes,
  ) async {
    try {
      await ref.read(queueProvider.notifier).replaceQueueAndPlay(
        episodes,
        ref.read(playbackControllerProvider),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not start playback. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Episode>> feedState = ref.watch(feedProvider);
    final FeedSortOrder sortOrder = ref.watch(feedSortProvider);
    final Set<String> downloadingGuids = ref.watch(downloadingEpisodesProvider);

    final List<Episode>? episodes = feedState.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minacast'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Play all',
            onPressed: (episodes != null && episodes.isNotEmpty)
                ? () => _playAll(context, ref, episodes)
                : null,
            icon: const Icon(Icons.playlist_play),
          ),
          IconButton(
            tooltip: sortOrder == FeedSortOrder.newestFirst
                ? 'Oldest first'
                : 'Newest first',
            onPressed: () => _toggleSort(ref),
            icon: Icon(
              sortOrder == FeedSortOrder.newestFirst
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
            ),
          ),
          IconButton(
            tooltip: 'Open queue',
            onPressed: () => _openQueue(context),
            icon: const Icon(Icons.queue_music_outlined),
          ),
          IconButton(
            tooltip: 'Search podcasts',
            onPressed: () => _openSearch(context),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: feedState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'We could not load your feed right now. Please try again.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (List<Episode> episodes) {
          if (episodes.isEmpty) {
            return _HomeEmptyState(onSearchPressed: () => _openSearch(context));
          }

          return RefreshIndicator(
            onRefresh: () => _refreshFeed(ref),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: episodes.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final Episode episode = episodes[index];
                final bool isDownloading =
                    downloadingGuids.contains(episode.guid);
                final bool isDownloaded = episode.localFilePath != null;
                return Dismissible(
                  key: ValueKey<String>(episode.guid),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Theme.of(context).colorScheme.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Played',
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle_outline,
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (DismissDirection direction) =>
                      _markAsPlayed(context, ref, episode),
                  child: GestureDetector(
                    onLongPress: () =>
                        _showDownloadMenu(context, ref, episode),
                    child: EpisodeListItem(
                      episode: episode,
                      onTap: () => _openEpisodeDetail(context, episode),
                      isDownloaded: isDownloaded,
                      isDownloading: isDownloading,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({required this.onSearchPressed});

  final VoidCallback onSearchPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.podcasts_outlined, size: 72, color: colors.outline),
            const SizedBox(height: 16),
            Text(
              'Your feed is empty.',
              style: textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Search for a podcast and subscribe to start filling your home feed.',
              style: textTheme.bodyMedium?.copyWith(color: colors.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onSearchPressed,
              icon: const Icon(Icons.search),
              label: const Text('Search Podcasts'),
            ),
          ],
        ),
      ),
    );
  }
}
