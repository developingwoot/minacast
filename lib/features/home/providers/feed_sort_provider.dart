import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FeedSortOrder { newestFirst, oldestFirst }

class FeedSortOrderNotifier extends Notifier<FeedSortOrder> {
  @override
  FeedSortOrder build() => FeedSortOrder.newestFirst;

  void toggle() {
    state = state == FeedSortOrder.newestFirst
        ? FeedSortOrder.oldestFirst
        : FeedSortOrder.newestFirst;
  }
}

final NotifierProvider<FeedSortOrderNotifier, FeedSortOrder> feedSortProvider =
    NotifierProvider<FeedSortOrderNotifier, FeedSortOrder>(
      FeedSortOrderNotifier.new,
    );
