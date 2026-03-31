import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks GUIDs of episodes currently being downloaded by the user via the
/// long-press manual download action. In-memory only — resets on app restart.
class DownloadingEpisodesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};

  void add(String guid) {
    state = <String>{...state, guid};
  }

  void remove(String guid) {
    state = state.where((String g) => g != guid).toSet();
  }
}

final NotifierProvider<DownloadingEpisodesNotifier, Set<String>>
    downloadingEpisodesProvider =
    NotifierProvider<DownloadingEpisodesNotifier, Set<String>>(
      DownloadingEpisodesNotifier.new,
    );
