import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/episode.dart';
import '../../../data/models/podcast.dart';
import '../../../data/providers/database_provider.dart';
import '../../home/providers/feed_provider.dart';
import '../../subscriptions/providers/subscriptions_provider.dart';
import '../services/rss_feed_service.dart';

class PodcastDetailState {
  const PodcastDetailState({
    required this.isSubscribed,
    required this.description,
    required this.episodes,
  });

  final bool isSubscribed;
  final String description;
  final List<Episode> episodes;

  PodcastDetailState copyWith({
    bool? isSubscribed,
    String? description,
    List<Episode>? episodes,
  }) {
    return PodcastDetailState(
      isSubscribed: isSubscribed ?? this.isSubscribed,
      description: description ?? this.description,
      episodes: episodes ?? this.episodes,
    );
  }
}

final Provider<RssFeedService> rssFeedServiceProvider =
    Provider<RssFeedService>((Ref ref) => RssFeedService());

// Type inferred — Riverpod does not export the family provider type publicly.
final podcastDetailProvider =
    AsyncNotifierProvider.family<
      PodcastDetailNotifier,
      PodcastDetailState,
      String
    >(PodcastDetailNotifier.new);

class PodcastDetailNotifier extends AsyncNotifier<PodcastDetailState> {
  PodcastDetailNotifier(this.rssUrl);

  final String rssUrl;

  @override
  Future<PodcastDetailState> build() async {
    final bool isSubscribed =
        await ref.read(databaseHelperProvider).getPodcastByUrl(rssUrl) != null;
    final PodcastFeedData feedData = await ref
        .read(rssFeedServiceProvider)
        .fetchFeed(rssUrl);

    return PodcastDetailState(
      isSubscribed: isSubscribed,
      description: feedData.description,
      episodes: feedData.episodes,
    );
  }

  Future<void> subscribe(Podcast podcast) async {
    final PodcastDetailState? current = state.value;
    if (current == null) {
      return;
    }

    final Podcast podcastToInsert = Podcast(
      rssUrl: podcast.rssUrl,
      title: podcast.title,
      author: podcast.author,
      description: current.description,
      artworkUrl: podcast.artworkUrl,
      lastCheckedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await ref
        .read(databaseHelperProvider)
        .insertPodcastWithEpisodes(podcastToInsert, current.episodes);

    ref.invalidate(feedProvider);
    ref.invalidate(subscriptionsProvider);
    state = AsyncData(current.copyWith(isSubscribed: true));
  }

  Future<void> unsubscribe() async {
    final PodcastDetailState? current = state.value;
    if (current == null) {
      return;
    }

    await ref.read(databaseHelperProvider).deletePodcast(rssUrl);
    ref.invalidate(feedProvider);
    ref.invalidate(subscriptionsProvider);
    state = AsyncData(current.copyWith(isSubscribed: false));
  }
}
