import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/episode.dart';
import '../../podcast_detail/widgets/episode_list_item.dart';
import '../../search/screens/search_screen.dart';
import '../providers/feed_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _openSearch(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const SearchScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Episode>> feedState = ref.watch(feedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minacast'),
        actions: <Widget>[
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

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: episodes.length,
            separatorBuilder: (BuildContext context, int index) =>
                const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              return EpisodeListItem(episode: episodes[index]);
            },
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
