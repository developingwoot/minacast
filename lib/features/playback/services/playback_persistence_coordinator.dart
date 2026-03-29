import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../data/database_helper.dart';
import '../../../data/models/episode.dart';
import '../models/playback_progress.dart';
import '../models/playback_ui_status.dart';
import 'playback_controller.dart';

class PlaybackPersistenceCoordinator {
  PlaybackPersistenceCoordinator({
    required PlaybackController controller,
    required DatabaseHelper databaseHelper,
  }) : _controller = controller,
       _databaseHelper = databaseHelper {
    _currentEpisode = _controller.currentEpisode;
    _currentProgress = _controller.currentProgress;
    _currentStatus = _controller.currentStatus;

    _subscriptions = <StreamSubscription<dynamic>>[
      _controller.episodeStream.listen(_handleEpisodeChanged),
      _controller.progressStream.listen((PlaybackProgress progress) {
        _currentProgress = progress;
        unawaited(_maybePersistProgress());
      }),
      _controller.statusStream.listen((PlaybackUiStatus status) {
        _currentStatus = status;
        if (status == PlaybackUiStatus.paused ||
            status == PlaybackUiStatus.idle ||
            status == PlaybackUiStatus.error) {
          unawaited(flushNow());
        }
      }),
    ];
  }

  final PlaybackController _controller;
  final DatabaseHelper _databaseHelper;
  late final List<StreamSubscription<dynamic>> _subscriptions;

  Episode? _currentEpisode;
  PlaybackProgress _currentProgress = PlaybackProgress.zero;
  PlaybackUiStatus _currentStatus = PlaybackUiStatus.idle;
  int _lastPersistedSeconds = 0;

  Future<void> _handleEpisodeChanged(Episode? nextEpisode) async {
    final Episode? previousEpisode = _currentEpisode;
    if (previousEpisode != null &&
        nextEpisode != null &&
        previousEpisode.guid == nextEpisode.guid) {
      return;
    }

    await flushNow();
    _currentEpisode = nextEpisode;
    _lastPersistedSeconds = 0;
  }

  Future<void> _maybePersistProgress() async {
    if (_currentEpisode == null || _currentStatus != PlaybackUiStatus.playing) {
      return;
    }

    final int positionSeconds = _currentProgress.position.inSeconds;
    if (positionSeconds <= 0) {
      return;
    }

    if (positionSeconds - _lastPersistedSeconds < 5) {
      return;
    }

    await _persistPosition(positionSeconds);
  }

  Future<void> _persistPosition(int positionSeconds) async {
    final Episode? episode = _currentEpisode;
    if (episode == null) {
      return;
    }

    await _databaseHelper.updateListenedPosition(episode.guid, positionSeconds);
    _lastPersistedSeconds = positionSeconds;
  }

  Future<void> flushNow() async {
    final Episode? episode = _currentEpisode;
    if (episode == null) {
      return;
    }

    final int positionSeconds = _currentProgress.position.inSeconds;
    if (positionSeconds <= 0) {
      return;
    }

    await _persistPosition(positionSeconds);
  }

  Future<void> handleAppLifecycleStateChanged(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      return;
    }

    await flushNow();
  }

  Future<void> dispose() async {
    await flushNow();
    for (final StreamSubscription<dynamic> subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
