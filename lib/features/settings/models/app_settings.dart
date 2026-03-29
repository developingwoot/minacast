class AppSettings {
  const AppSettings({
    required this.darkMode,
    required this.playbackSpeed,
    required this.sleepTimerDefaultMinutes,
  });

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
}
