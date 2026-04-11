import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/podcast.dart';
import '../../podcast_detail/screens/podcast_detail_screen.dart';
import '../../search/providers/search_provider.dart';
import '../../search/widgets/podcast_card.dart';
import '../providers/subscriptions_provider.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    ref.read(searchProvider.notifier).search(value);
  }

  void _onClear() {
    _controller.clear();
    setState(() {});
    ref.read(searchProvider.notifier).clear();
  }

  void _openDetail(BuildContext context, Podcast podcast) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PodcastDetailScreen(podcast: podcast),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSearching = _controller.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: TextField(
          controller: _controller,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: 'Search podcasts...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: isSearching
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _onClear,
                  )
                : null,
          ),
          textInputAction: TextInputAction.search,
        ),
      ),
      body: isSearching ? _SearchResults(controller: _controller, onTap: _openDetail) : _SubscriptionsList(onTap: _openDetail),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.controller, required this.onTap});

  final TextEditingController controller;
  final void Function(BuildContext, Podcast) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Podcast>> searchState = ref.watch(searchProvider);

    return searchState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Something went wrong while searching. Please try again.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
      data: (List<Podcast> podcasts) {
        if (podcasts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No podcasts found for "${controller.text}".',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: podcasts.length,
          separatorBuilder: (BuildContext context, int index) =>
              const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            final Podcast podcast = podcasts[index];
            return PodcastCard(
              podcast: podcast,
              onTap: () => onTap(context, podcast),
            );
          },
        );
      },
    );
  }
}

class _SubscriptionsList extends ConsumerWidget {
  const _SubscriptionsList({required this.onTap});

  final void Function(BuildContext, Podcast) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Podcast>> subsState = ref.watch(subscriptionsProvider);

    return subsState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object error, StackTrace stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Failed to load subscriptions.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
      data: (List<Podcast> podcasts) {
        if (podcasts.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.podcasts,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Subscribe to your first podcast by searching above.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          itemCount: podcasts.length,
          separatorBuilder: (BuildContext context, int index) =>
              const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            final Podcast podcast = podcasts[index];
            return PodcastCard(
              podcast: podcast,
              onTap: () => onTap(context, podcast),
            );
          },
        );
      },
    );
  }
}
