class AppSettings {
  const AppSettings({
    required this.darkMode,
    required this.playbackSpeed,
    required this.sleepTimerDefaultMinutes,
  });

  static const List<double> supportedPlaybackSpeeds = <double>[
    0.5,
    1.0,
    1.5,
    2.0,
  ];
  static const List<int> supportedSleepTimerMinutes = <int>[15, 30, 45, 60];

  final bool darkMode;
  final double playbackSpeed;
  final int sleepTimerDefaultMinutes;

  static const AppSettings defaults = AppSettings(
    darkMode: false,
    playbackSpeed: 1.0,
    sleepTimerDefaultMinutes: 30,
  );

  AppSettings copyWith({
    bool? darkMode,
    double? playbackSpeed,
    int? sleepTimerDefaultMinutes,
  }) {
    return AppSettings(
      darkMode: darkMode ?? this.darkMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      sleepTimerDefaultMinutes:
          sleepTimerDefaultMinutes ?? this.sleepTimerDefaultMinutes,
    );
  }

  static double normalizePlaybackSpeed(double value) {
    if (supportedPlaybackSpeeds.contains(value)) {
      return value;
    }
    return defaults.playbackSpeed;
  }

  static int normalizeSleepTimerDefaultMinutes(int value) {
    if (supportedSleepTimerMinutes.contains(value)) {
      return value;
    }
    return defaults.sleepTimerDefaultMinutes;
  }
}
