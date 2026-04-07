import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/database_provider.dart';

enum FeedSortOrder { newestFirst, oldestFirst }

class FeedSortOrderNotifier extends AsyncNotifier<FeedSortOrder> {
  @override
  Future<FeedSortOrder> build() async {
    final String? value = await ref
        .read(databaseHelperProvider)
        .getSetting('feed_sort_order');
    return value == 'oldest_first'
        ? FeedSortOrder.oldestFirst
        : FeedSortOrder.newestFirst;
  }

  Future<void> toggle() async {
    final FeedSortOrder current =
        state.value ?? FeedSortOrder.newestFirst;
    final FeedSortOrder next = current == FeedSortOrder.newestFirst
        ? FeedSortOrder.oldestFirst
        : FeedSortOrder.newestFirst;
    state = AsyncData<FeedSortOrder>(next);
    await ref.read(databaseHelperProvider).setSetting(
      'feed_sort_order',
      next == FeedSortOrder.newestFirst ? 'newest_first' : 'oldest_first',
    );
  }
}

final AsyncNotifierProvider<FeedSortOrderNotifier, FeedSortOrder>
feedSortProvider =
    AsyncNotifierProvider<FeedSortOrderNotifier, FeedSortOrder>(
      FeedSortOrderNotifier.new,
    );
