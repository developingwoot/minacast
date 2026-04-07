import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/episode.dart';
import '../../../data/providers/database_provider.dart';
import 'feed_sort_provider.dart';

final FutureProvider<List<Episode>> feedProvider =
    FutureProvider<List<Episode>>((Ref ref) async {
      final FeedSortOrder sortOrder = await ref.watch(feedSortProvider.future);
      return ref.read(databaseHelperProvider).getAllEpisodesSortedByDate(
        ascending: sortOrder == FeedSortOrder.oldestFirst,
      );
    });
