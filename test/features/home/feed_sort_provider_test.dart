import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:minacast/data/database_helper.dart';
import 'package:minacast/features/home/providers/feed_sort_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.useInMemoryDatabaseForTests();
  });

  setUp(() async {
    await DatabaseHelper.instance.resetForTest();
  });

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('defaults to newestFirst when no setting exists', () async {
    final ProviderContainer container = makeContainer();
    final FeedSortOrder order =
        await container.read(feedSortProvider.future);
    expect(order, FeedSortOrder.newestFirst);
  });

  test('toggle saves oldestFirst to DB and updates state', () async {
    final ProviderContainer container = makeContainer();
    await container.read(feedSortProvider.future);

    await container.read(feedSortProvider.notifier).toggle();

    expect(
      container.read(feedSortProvider).value,
      FeedSortOrder.oldestFirst,
    );
    final String? saved =
        await DatabaseHelper.instance.getSetting('feed_sort_order');
    expect(saved, 'oldest_first');
  });

  test('toggle back saves newest_first to DB and updates state', () async {
    final ProviderContainer container = makeContainer();
    await container.read(feedSortProvider.future);
    await container.read(feedSortProvider.notifier).toggle(); // → oldest
    await container.read(feedSortProvider.notifier).toggle(); // → newest

    expect(
      container.read(feedSortProvider).value,
      FeedSortOrder.newestFirst,
    );
    final String? saved =
        await DatabaseHelper.instance.getSetting('feed_sort_order');
    expect(saved, 'newest_first');
  });

  test('new container reads persisted value from DB', () async {
    // First container: toggle to oldestFirst and persist
    final ProviderContainer container1 = makeContainer();
    await container1.read(feedSortProvider.future);
    await container1.read(feedSortProvider.notifier).toggle();

    // Second container: should load oldestFirst from DB
    final ProviderContainer container2 = makeContainer();
    final FeedSortOrder order =
        await container2.read(feedSortProvider.future);
    expect(order, FeedSortOrder.oldestFirst);
  });
}
