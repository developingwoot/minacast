import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../../data/database_helper.dart';
import '../../../data/models/episode.dart';
import '../../../data/models/podcast.dart';
import '../models/playback_progress.dart';
import '../models/playback_ui_status.dart';
import '../models/sleep_timer_state.dart';
import 'playback_controller.dart';
import 'playback_media_mapper.dart';
import 'queue_autoplay_service.dart';

class PodcastAudioHandler extends BaseAudioHandler
    with SeekHandler
    implements PlaybackController {
  PodcastAudioHandler({
    required DatabaseHelper databaseHelper,
    QueueAutoplayService? queueAutoplayService,
  }) : _databaseHelper = databaseHelper,
       _queueAutoplayService =
           queueAutoplayService ??
           QueueAutoplayService(databaseHelper: databaseHelper),
       _player = AudioPlayer() {
    _listenToPlayer();
    _emitEpisode(_currentEpisode);
    _emitMediaItem(_currentMediaItem);
    _emitStatus(_currentStatus);
    _emitProgress();
    _emitSpeed(_currentSpeed);
    _emitSleepTimerState(_currentSleepTimerState);
  }

  final DatabaseHelper _databaseHelper;
  final QueueAutoplayService _queueAutoplayService;
  final AudioPlayer _player;

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

  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  Episode? _currentEpisode;
  MediaItem? _currentMediaItem;
  PlaybackUiStatus _currentStatus = PlaybackUiStatus.idle;
  PlaybackProgress _currentProgress = PlaybackProgress.zero;
  double _currentSpeed = 1.0;
  SleepTimerState _currentSleepTimerState = SleepTimerState.inactive;
  Timer? _sleepTimer;
  DateTime? _sleepTimerEndsAt;

  @override
  Episode? get currentEpisode => _currentEpisode;

  @override
  MediaItem? get currentMediaItem => _currentMediaItem;

  @override
  PlaybackUiStatus get currentStatus => _currentStatus;

  @override
  PlaybackProgress get currentProgress => _currentProgress;

  @override
  double get currentSpeed => _currentSpeed;

  @override
  SleepTimerState get currentSleepTimerState => _currentSleepTimerState;

  @override
  Stream<Episode?> get episodeStream => _episodeController.stream;

  @override
  Stream<MediaItem?> get mediaItemStream => _mediaItemController.stream;

  @override
  Stream<PlaybackUiStatus> get statusStream => _statusController.stream;

  @override
  Stream<PlaybackProgress> get progressStream => _progressController.stream;

  @override
  Stream<double> get speedStream => _speedController.stream;

  @override
  Stream<SleepTimerState> get sleepTimerStream => _sleepTimerController.stream;

  void _listenToPlayer() {
    _subscriptions.add(
      _player.playerStateStream.listen((PlayerState playerState) {
        final ProcessingState processingState = playerState.processingState;
        if (processingState == ProcessingState.completed) {
          unawaited(_handlePlaybackCompleted());
          return;
        }

        final PlaybackUiStatus nextStatus;
        if (processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering) {
          nextStatus = PlaybackUiStatus.loading;
        } else if (playerState.playing) {
          nextStatus = PlaybackUiStatus.playing;
        } else if (_currentEpisode == null) {
          nextStatus = PlaybackUiStatus.idle;
        } else {
          nextStatus = PlaybackUiStatus.paused;
        }

        _emitStatus(nextStatus);
        _broadcastPlaybackState();
      }),
    );

    _subscriptions.add(
      _player.positionStream.listen((Duration position) {
        _currentProgress = _currentProgress.copyWith(position: position);
        _emitProgress();
        _broadcastPlaybackState();
      }),
    );

    _subscriptions.add(
      _player.durationStream.listen((Duration? duration) {
        _currentProgress = _currentProgress.copyWith(
          duration: duration ?? Duration.zero,
        );
        _emitProgress();
        if (_currentMediaItem != null && duration != null) {
          _currentMediaItem = _currentMediaItem!.copyWith(duration: duration);
          mediaItem.add(_currentMediaItem);
          _emitMediaItem(_currentMediaItem);
        }
      }),
    );

    _subscriptions.add(
      _player.speedStream.listen((double speed) {
        _emitSpeed(speed);
        _broadcastPlaybackState();
      }),
    );
  }

  Future<Podcast?> _loadPodcastMetadata(String rssUrl) async {
    if (rssUrl.isEmpty) {
      return null;
    }

    return _databaseHelper.getPodcastByUrl(rssUrl);
  }

  Future<double> _loadSavedPlaybackSpeed() async {
    final String? rawValue = await _databaseHelper.getSetting('playback_speed');
    return double.tryParse(rawValue ?? '1.0') ?? 1.0;
  }

  String _formatPlaybackSpeed(double speed) {
    return speed.toStringAsFixed(1);
  }

  Future<Duration> _loadResumePosition(Episode episode) async {
    final Episode? storedEpisode = await _databaseHelper.getEpisodeByGuid(
      episode.guid,
    );
    if (storedEpisode == null || storedEpisode.isCompleted == 1) {
      return Duration.zero;
    }

    return Duration(seconds: storedEpisode.listenedPositionSeconds);
  }

  Future<AudioSource> _buildAudioSource(Episode episode) async {
    final String source = episode.localFilePath ?? episode.audioUrl;
    final Uri uri = episode.localFilePath != null
        ? Uri.file(source)
        : Uri.parse(source);
    return AudioSource.uri(uri);
  }

  @override
  Future<void> playEpisode(Episode episode) async {
    try {
      await cancelSleepTimer();
      _emitStatus(PlaybackUiStatus.loading);

      final Podcast? podcast = await _loadPodcastMetadata(
        episode.podcastRssUrl,
      );
      final MediaItem nextMediaItem = mediaItemFromEpisode(
        episode,
        podcast: podcast,
      );
      final double savedSpeed = await _loadSavedPlaybackSpeed();
      final Duration resumePosition = await _loadResumePosition(episode);
      final AudioSource audioSource = await _buildAudioSource(episode);

      _currentEpisode = episode;
      _emitEpisode(episode);
      _currentMediaItem = nextMediaItem;
      mediaItem.add(nextMediaItem);
      _emitMediaItem(nextMediaItem);

      await _player.setSpeed(savedSpeed);
      await _player.setAudioSource(
        audioSource,
        initialPosition: resumePosition,
      );
      _currentProgress = PlaybackProgress(
        position: resumePosition,
        duration: _player.duration ?? Duration.zero,
      );
      _emitProgress();
      await _player.play();
    } catch (_) {
      _emitStatus(PlaybackUiStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> stop() async {
    await stopPlayback();
  }

  @override
  Future<void> stopPlayback() async {
    await cancelSleepTimer();
    await _player.stop();
    _currentEpisode = null;
    _currentMediaItem = null;
    _currentProgress = PlaybackProgress.zero;
    mediaItem.add(null);
    _emitEpisode(null);
    _emitMediaItem(null);
    _emitProgress();
    _emitStatus(PlaybackUiStatus.idle);
    _broadcastPlaybackState();
  }

  @override
  Future<void> togglePlayPause() async {
    if (_currentEpisode == null) {
      return;
    }

    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipForward30() async {
    final Duration target = _player.position + const Duration(seconds: 30);
    final Duration cappedTarget = target > _currentProgress.duration
        ? _currentProgress.duration
        : target;
    await seek(cappedTarget);
  }

  @override
  Future<void> skipBackward30() async {
    final Duration target = _player.position - const Duration(seconds: 30);
    await seek(target.isNegative ? Duration.zero : target);
  }

  @override
  Future<void> fastForward() async {
    await skipForward30();
  }

  @override
  Future<void> rewind() async {
    await skipBackward30();
  }

  @override
  Future<void> skipToNext() async {
    await skipForward30();
  }

  @override
  Future<void> skipToPrevious() async {
    await skipBackward30();
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    await _player.setSpeed(speed);
    await _databaseHelper.setSetting(
      'playback_speed',
      _formatPlaybackSpeed(speed),
    );
  }

  @override
  Future<int> loadSleepTimerDefaultMinutes() async {
    final String? rawValue = await _databaseHelper.getSetting(
      'sleep_timer_default_minutes',
    );
    return int.tryParse(rawValue ?? '30') ?? 30;
  }

  @override
  Future<void> startSleepTimer(Duration duration) async {
    await cancelSleepTimer();

    if (duration <= Duration.zero) {
      return;
    }

    _sleepTimerEndsAt = DateTime.now().add(duration);
    _emitSleepTimerState(SleepTimerState(isActive: true, remaining: duration));

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      final DateTime? endsAt = _sleepTimerEndsAt;
      if (endsAt == null) {
        return;
      }

      final Duration remaining = endsAt.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        unawaited(stopPlayback());
        unawaited(cancelSleepTimer());
        return;
      }

      _emitSleepTimerState(
        SleepTimerState(isActive: true, remaining: remaining),
      );
    });
  }

  @override
  Future<void> cancelSleepTimer() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndsAt = null;
    _emitSleepTimerState(SleepTimerState.inactive);
  }

  Future<void> _handlePlaybackCompleted() async {
    final Episode? completedEpisode = _currentEpisode;
    if (completedEpisode != null) {
      final Episode? nextEpisode = await _queueAutoplayService
          .completeEpisodeAndLoadNext(completedEpisode);
      if (nextEpisode != null) {
        await playEpisode(nextEpisode);
        return;
      }
    }

    _emitStatus(PlaybackUiStatus.completed);
    await stopPlayback();
  }

  AudioProcessingState _mapProcessingState(ProcessingState processingState) {
    switch (processingState) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  void _broadcastPlaybackState() {
    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.rewind,
          _player.playing ? MediaControl.pause : MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const <MediaAction>{
          MediaAction.play,
          MediaAction.pause,
          MediaAction.seek,
          MediaAction.stop,
          MediaAction.rewind,
          MediaAction.fastForward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
        },
        androidCompactActionIndices: const <int>[0, 1, 3],
        processingState: _mapProcessingState(_player.processingState),
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ),
    );
  }

  void _emitEpisode(Episode? episode) {
    _currentEpisode = episode;
    _episodeController.add(episode);
  }

  void _emitMediaItem(MediaItem? item) {
    _currentMediaItem = item;
    _mediaItemController.add(item);
  }

  void _emitStatus(PlaybackUiStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void _emitProgress() {
    _progressController.add(_currentProgress);
  }

  void _emitSpeed(double speed) {
    _currentSpeed = speed;
    _speedController.add(speed);
  }

  void _emitSleepTimerState(SleepTimerState state) {
    _currentSleepTimerState = state;
    _sleepTimerController.add(state);
  }

  Future<void> disposeHandler() async {
    await cancelSleepTimer();
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _episodeController.close();
    await _mediaItemController.close();
    await _statusController.close();
    await _progressController.close();
    await _speedController.close();
    await _sleepTimerController.close();
    await _player.dispose();
  }
}
