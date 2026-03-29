import 'package:audio_service/audio_service.dart';

import '../../../data/models/episode.dart';
import '../models/playback_progress.dart';
import '../models/playback_ui_status.dart';
import '../models/sleep_timer_state.dart';

abstract class PlaybackController {
  Episode? get currentEpisode;
  MediaItem? get currentMediaItem;
  PlaybackUiStatus get currentStatus;
  PlaybackProgress get currentProgress;
  double get currentSpeed;
  SleepTimerState get currentSleepTimerState;

  Stream<Episode?> get episodeStream;
  Stream<MediaItem?> get mediaItemStream;
  Stream<PlaybackUiStatus> get statusStream;
  Stream<PlaybackProgress> get progressStream;
  Stream<double> get speedStream;
  Stream<SleepTimerState> get sleepTimerStream;

  Future<void> playEpisode(Episode episode);
  Future<void> togglePlayPause();
  Future<void> seek(Duration position);
  Future<void> skipForward30();
  Future<void> skipBackward30();
  Future<void> setPlaybackSpeed(double speed);
  Future<int> loadSleepTimerDefaultMinutes();
  Future<void> startSleepTimer(Duration duration);
  Future<void> cancelSleepTimer();
  Future<void> stopPlayback();
}
