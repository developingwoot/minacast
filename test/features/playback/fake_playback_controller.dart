import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'package:minacast/data/models/episode.dart';
import 'package:minacast/features/playback/models/playback_progress.dart';
import 'package:minacast/features/playback/models/playback_ui_status.dart';
import 'package:minacast/features/playback/models/sleep_timer_state.dart';
import 'package:minacast/features/playback/services/playback_controller.dart';

class FakePlaybackController implements PlaybackController {
  Episode? _currentEpisode;
  MediaItem? _currentMediaItem;
  PlaybackUiStatus _currentStatus = PlaybackUiStatus.idle;
  PlaybackProgress _currentProgress = PlaybackProgress.zero;
  double _currentSpeed = 1.0;
  SleepTimerState _currentSleepTimerState = SleepTimerState.inactive;

  final StreamController<Episode?> _episodeController =
      StreamController<Episode?>.broadcast();
  final StreamController<MediaItem?> _mediaItemController =
      StreamController<MediaItem?>.broadcast();
  final StreamController<PlaybackUiStatus> _statusController =
      StreamController<PlaybackUiStatus>.broadcast();
  final StreamController<PlaybackProgress> _progressController =
      StreamController<PlaybackProgress>.broadcast();
  final StreamController<double> _speedController =
      StreamController<double>.broadcast();
  final StreamController<SleepTimerState> _sleepTimerController =
      StreamController<SleepTimerState>.broadcast();

  int togglePlayPauseCalls = 0;
  int skipForwardCalls = 0;
  int skipBackwardCalls = 0;
  int playEpisodeCalls = 0;
  int seekCalls = 0;
  int setSpeedCalls = 0;
  int startSleepTimerCalls = 0;
  int cancelSleepTimerCalls = 0;
  int stopPlaybackCalls = 0;

  Duration? lastSeekPosition;
  double? lastSetSpeed;
  Duration? lastSleepTimerDuration;
  Episode? lastPlayedEpisode;

  @override
  Episode? get currentEpisode => _currentEpisode;

  @override
  MediaItem? get currentMediaItem => _currentMediaItem;

  @override
  PlaybackProgress get currentProgress => _currentProgress;

  @override
  SleepTimerState get currentSleepTimerState => _currentSleepTimerState;

  @override
  double get currentSpeed => _currentSpeed;

  @override
  PlaybackUiStatus get currentStatus => _currentStatus;

  @override
  Stream<Episode?> get episodeStream => _episodeController.stream;

  @override
  Stream<MediaItem?> get mediaItemStream => _mediaItemController.stream;

  @override
  Stream<PlaybackProgress> get progressStream => _progressController.stream;

  @override
  Stream<SleepTimerState> get sleepTimerStream => _sleepTimerController.stream;

  @override
  Stream<double> get speedStream => _speedController.stream;

  @override
  Stream<PlaybackUiStatus> get statusStream => _statusController.stream;

  void emitEpisode(Episode? episode) {
    _currentEpisode = episode;
    _episodeController.add(episode);
  }

  void emitMediaItem(MediaItem? mediaItem) {
    _currentMediaItem = mediaItem;
    _mediaItemController.add(mediaItem);
  }

  void emitStatus(PlaybackUiStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void emitProgress(PlaybackProgress progress) {
    _currentProgress = progress;
    _progressController.add(progress);
  }

  void emitSpeed(double speed) {
    _currentSpeed = speed;
    _speedController.add(speed);
  }

  void emitSleepTimerState(SleepTimerState state) {
    _currentSleepTimerState = state;
    _sleepTimerController.add(state);
  }

  @override
  Future<void> cancelSleepTimer() async {
    cancelSleepTimerCalls += 1;
    emitSleepTimerState(SleepTimerState.inactive);
  }

  @override
  Future<int> loadSleepTimerDefaultMinutes() async => 30;

  @override
  Future<void> playEpisode(Episode episode) async {
    playEpisodeCalls += 1;
    lastPlayedEpisode = episode;
    emitEpisode(episode);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls += 1;
    lastSeekPosition = position;
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    setSpeedCalls += 1;
    lastSetSpeed = speed;
    emitSpeed(speed);
  }

  @override
  Future<void> skipBackward30() async {
    skipBackwardCalls += 1;
  }

  @override
  Future<void> skipForward30() async {
    skipForwardCalls += 1;
  }

  @override
  Future<void> startSleepTimer(Duration duration) async {
    startSleepTimerCalls += 1;
    lastSleepTimerDuration = duration;
    emitSleepTimerState(SleepTimerState(isActive: true, remaining: duration));
  }

  @override
  Future<void> stopPlayback() async {
    stopPlaybackCalls += 1;
  }

  @override
  Future<void> togglePlayPause() async {
    togglePlayPauseCalls += 1;
  }

  Future<void> dispose() async {
    await _episodeController.close();
    await _mediaItemController.close();
    await _statusController.close();
    await _progressController.close();
    await _speedController.close();
    await _sleepTimerController.close();
  }
}
