import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/episode.dart';
import '../../../data/providers/database_provider.dart';

final FutureProvider<List<Episode>> feedProvider =
    FutureProvider<List<Episode>>((Ref ref) async {
      return ref.read(databaseHelperProvider).getAllEpisodesSortedByDate();
    });
