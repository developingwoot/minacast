import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/episode.dart';
import '../../../data/providers/database_provider.dart';
import '../models/playback_progress.dart';
import '../models/playback_ui_status.dart';
import '../models/sleep_timer_state.dart';
import '../services/playback_controller.dart';
import '../services/playback_persistence_coordinator.dart';

class PlaybackViewState {
  const PlaybackViewState({
    required this.currentEpisode,
    required this.currentMediaItem,
    required this.currentStatus,
    required this.currentProgress,
    required this.currentSpeed,
    required this.currentSleepTimerState,
  });

  final Episode? currentEpisode;
  final MediaItem? currentMediaItem;
  final PlaybackUiStatus currentStatus;
  final PlaybackProgress currentProgress;
  final double currentSpeed;
  final SleepTimerState currentSleepTimerState;

  PlaybackViewState copyWith({
    Object? currentEpisode = _sentinel,
    Object? currentMediaItem = _sentinel,
    PlaybackUiStatus? currentStatus,
    PlaybackProgress? currentProgress,
    double? currentSpeed,
    SleepTimerState? currentSleepTimerState,
  }) {
    return PlaybackViewState(
      currentEpisode: currentEpisode == _sentinel
          ? this.currentEpisode
          : currentEpisode as Episode?,
      currentMediaItem: currentMediaItem == _sentinel
          ? this.currentMediaItem
          : currentMediaItem as MediaItem?,
      currentStatus: currentStatus ?? this.currentStatus,
      currentProgress: currentProgress ?? this.currentProgress,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentSleepTimerState:
          currentSleepTimerState ?? this.currentSleepTimerState,
    );
  }

  static const Object _sentinel = Object();
}

class PlaybackStateNotifier extends Notifier<PlaybackViewState> {
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  @override
  PlaybackViewState build() {
    final PlaybackController controller = ref.watch(playbackControllerProvider);

    ref.onDispose(() {
      for (final StreamSubscription<dynamic> subscription in _subscriptions) {
        unawaited(subscription.cancel());
      }
    });

    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      controller.episodeStream.listen((Episode? episode) {
        state = state.copyWith(currentEpisode: episode);
      }),
      controller.mediaItemStream.listen((MediaItem? mediaItem) {
        state = state.copyWith(currentMediaItem: mediaItem);
      }),
      controller.statusStream.listen((PlaybackUiStatus status) {
        state = state.copyWith(currentStatus: status);
      }),
      controller.progressStream.listen((PlaybackProgress progress) {
        state = state.copyWith(currentProgress: progress);
      }),
      controller.speedStream.listen((double speed) {
        state = state.copyWith(currentSpeed: speed);
      }),
      controller.sleepTimerStream.listen((SleepTimerState sleepTimerState) {
        state = state.copyWith(currentSleepTimerState: sleepTimerState);
      }),
    ]);

    return PlaybackViewState(
      currentEpisode: controller.currentEpisode,
      currentMediaItem: controller.currentMediaItem,
      currentStatus: controller.currentStatus,
      currentProgress: controller.currentProgress,
      currentSpeed: controller.currentSpeed,
      currentSleepTimerState: controller.currentSleepTimerState,
    );
  }
}

final Provider<PlaybackController> audioHandlerProvider =
    Provider<PlaybackController>((Ref ref) {
      return const _NoOpPlaybackController();
    });

final Provider<PlaybackController> playbackControllerProvider =
    Provider<PlaybackController>((Ref ref) {
      return ref.watch(audioHandlerProvider);
    });

final NotifierProvider<PlaybackStateNotifier, PlaybackViewState>
playbackStateProvider =
    NotifierProvider<PlaybackStateNotifier, PlaybackViewState>(
      PlaybackStateNotifier.new,
    );

final Provider<Episode?> currentPlaybackEpisodeProvider =
    Provider<Episode?>((Ref ref) {
      return ref.watch(
        playbackStateProvider.select(
          (PlaybackViewState value) => value.currentEpisode,
        ),
      );
    });

final Provider<PlaybackUiStatus> playbackStatusProvider =
    Provider<PlaybackUiStatus>((Ref ref) {
      return ref.watch(
        playbackStateProvider.select(
          (PlaybackViewState value) => value.currentStatus,
        ),
      );
    });

final Provider<PlaybackProgress> playbackProgressProvider =
    Provider<PlaybackProgress>((Ref ref) {
      return ref.watch(
        playbackStateProvider.select(
          (PlaybackViewState value) => value.currentProgress,
        ),
      );
    });

final Provider<double> playbackSpeedProvider = Provider<double>((Ref ref) {
  return ref.watch(
    playbackStateProvider.select(
      (PlaybackViewState value) => value.currentSpeed,
    ),
  );
});

final Provider<SleepTimerState> sleepTimerStateProvider =
    Provider<SleepTimerState>((Ref ref) {
      return ref.watch(
        playbackStateProvider.select(
          (PlaybackViewState value) => value.currentSleepTimerState,
        ),
      );
    });

final Provider<bool> miniPlayerVisibleProvider = Provider<bool>((Ref ref) {
  return ref.watch(currentPlaybackEpisodeProvider) != null;
});

final Provider<PlaybackPersistenceCoordinator>
playbackPersistenceCoordinatorProvider =
    Provider<PlaybackPersistenceCoordinator>((Ref ref) {
      final PlaybackPersistenceCoordinator coordinator =
          PlaybackPersistenceCoordinator(
            controller: ref.watch(playbackControllerProvider),
            databaseHelper: ref.watch(databaseHelperProvider),
          );
      ref.onDispose(() {
        unawaited(coordinator.dispose());
      });
      return coordinator;
    });

class _NoOpPlaybackController implements PlaybackController {
  const _NoOpPlaybackController();

  @override
  Episode? get currentEpisode => null;

  @override
  MediaItem? get currentMediaItem => null;

  @override
  PlaybackProgress get currentProgress => PlaybackProgress.zero;

  @override
  SleepTimerState get currentSleepTimerState => SleepTimerState.inactive;

  @override
  double get currentSpeed => 1.0;

  @override
  PlaybackUiStatus get currentStatus => PlaybackUiStatus.idle;

  @override
  Stream<Episode?> get episodeStream => const Stream<Episode?>.empty();

  @override
  Stream<MediaItem?> get mediaItemStream => const Stream<MediaItem?>.empty();

  @override
  Stream<PlaybackProgress> get progressStream =>
      const Stream<PlaybackProgress>.empty();

  @override
  Stream<SleepTimerState> get sleepTimerStream =>
      const Stream<SleepTimerState>.empty();

  @override
  Stream<double> get speedStream => const Stream<double>.empty();

  @override
  Stream<PlaybackUiStatus> get statusStream =>
      const Stream<PlaybackUiStatus>.empty();

  @override
  Future<void> cancelSleepTimer() async {}

  @override
  Future<int> loadSleepTimerDefaultMinutes() async => 30;

  @override
  Future<void> playEpisode(Episode episode) async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> skipBackward30() async {}

  @override
  Future<void> skipForward30() async {}

  @override
  Future<void> startSleepTimer(Duration duration) async {}

  @override
  Future<void> stopPlayback() async {}

  @override
  Future<void> togglePlayPause() async {}
}
