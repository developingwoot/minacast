import 'package:flutter/foundation.dart';

@immutable
class PlaybackProgress {
  const PlaybackProgress({
    required this.position,
    required this.duration,
  });

  final Duration position;
  final Duration duration;

  static const PlaybackProgress zero = PlaybackProgress(
    position: Duration.zero,
    duration: Duration.zero,
  );

  PlaybackProgress copyWith({
    Duration? position,
    Duration? duration,
  }) {
    return PlaybackProgress(
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}
