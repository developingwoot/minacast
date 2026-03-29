import 'package:flutter/foundation.dart';

@immutable
class SleepTimerState {
  const SleepTimerState({
    required this.isActive,
    this.remaining,
  });

  final bool isActive;
  final Duration? remaining;

  static const SleepTimerState inactive = SleepTimerState(isActive: false);
}
