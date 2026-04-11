import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/podcast.dart';
import '../../../data/providers/database_provider.dart';

final FutureProvider<List<Podcast>> subscriptionsProvider =
    FutureProvider<List<Podcast>>((Ref ref) async {
      return ref.read(databaseHelperProvider).getAllPodcasts();
    });
