import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/podcast.dart';
import '../../episode_detail/screens/episode_detail_screen.dart';
import '../providers/podcast_detail_provider.dart';
import '../widgets/episode_list_item.dart';

class PodcastDetailScreen extends ConsumerWidget {
  const PodcastDetailScreen({super.key, required this.podcast});

  final Podcast podcast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PodcastDetailState> detailState = ref.watch(
      podcastDetailProvider(podcast.rssUrl),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          podcast.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: detailState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load this podcast feed. Please try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(podcastDetailProvider(podcast.rssUrl)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (PodcastDetailState detail) =>
            _PodcastDetailBody(podcast: podcast, detail: detail),
      ),
    );
  }
}

class _PodcastDetailBody extends ConsumerWidget {
  const _PodcastDetailBody({required this.podcast, required this.detail});

  final Podcast podcast;
  final PodcastDetailState detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: podcast.artworkUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (BuildContext context, String url) =>
                        _ArtworkFallback(colors: colors),
                    errorWidget:
                        (BuildContext context, String url, Object error) =>
                            _ArtworkFallback(colors: colors),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        podcast.title,
                        style: text.titleMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (podcast.author.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          podcast.author,
                          style: text.bodySmall?.copyWith(
                            color: colors.outline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SubscribeButton(podcast: podcast, detail: detail),
          ),
        ),
        if (detail.description.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Text(detail.description, style: text.bodyMedium),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              '${detail.episodes.length} episode${detail.episodes.length == 1 ? '' : 's'}',
              style: text.titleSmall,
            ),
          ),
        ),
        if (detail.episodes.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No episodes found.',
                style: text.bodyMedium?.copyWith(color: colors.outline),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: detail.episodes.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final episode = detail.episodes[index];
              return EpisodeListItem(
                episode: episode,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) =>
                        EpisodeDetailScreen(episode: episode),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _SubscribeButton extends ConsumerStatefulWidget {
  const _SubscribeButton({required this.podcast, required this.detail});

  final Podcast podcast;
  final PodcastDetailState detail;

  @override
  ConsumerState<_SubscribeButton> createState() => _SubscribeButtonState();
}

class _SubscribeButtonState extends ConsumerState<_SubscribeButton> {
  bool _loading = false;

  Future<void> _toggle() async {
    setState(() {
      _loading = true;
    });

    try {
      final PodcastDetailNotifier notifier = ref.read(
        podcastDetailProvider(widget.podcast.rssUrl).notifier,
      );
      if (widget.detail.isSubscribed) {
        await notifier.unsubscribe();
      } else {
        await notifier.subscribe(widget.podcast);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.detail.isSubscribed) {
      return OutlinedButton.icon(
        onPressed: _toggle,
        icon: const Icon(Icons.check),
        label: const Text('Subscribed'),
      );
    }

    return FilledButton.icon(
      onPressed: _toggle,
      icon: const Icon(Icons.add),
      label: const Text('Subscribe'),
    );
  }
}

class _ArtworkFallback extends StatelessWidget {
  const _ArtworkFallback({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      color: colors.surfaceContainerHighest,
      child: const Icon(Icons.podcasts, size: 40),
    );
  }
}
