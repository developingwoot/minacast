import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/podcast.dart';
import '../services/podcast_search_service.dart';

final Provider<PodcastSearchService> podcastSearchServiceProvider =
    Provider<PodcastSearchService>((Ref ref) => PodcastSearchService());

final Provider<Duration> searchDebounceDurationProvider = Provider<Duration>(
  (Ref ref) => const Duration(milliseconds: 400),
);

final AsyncNotifierProvider<SearchNotifier, List<Podcast>> searchProvider =
    AsyncNotifierProvider<SearchNotifier, List<Podcast>>(SearchNotifier.new);

class SearchNotifier extends AsyncNotifier<List<Podcast>> {
  Timer? _debounce;

  @override
  Future<List<Podcast>> build() async {
    ref.onDispose(() {
      _debounce?.cancel();
    });
    return <Podcast>[];
  }

  void search(String query) {
    _debounce?.cancel();

    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      state = const AsyncData(<Podcast>[]);
      return;
    }

    final Duration debounceDuration = ref.read(searchDebounceDurationProvider);
    _debounce = Timer(debounceDuration, () async {
      state = const AsyncLoading();
      state = await AsyncValue.guard(
        () => ref.read(podcastSearchServiceProvider).search(trimmedQuery),
      );
    });
  }

  void clear() {
    _debounce?.cancel();
    state = const AsyncData(<Podcast>[]);
  }
}
