import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database_helper.dart';
import '../../../data/providers/database_provider.dart';
import '../models/app_settings.dart';

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  DatabaseHelper get _databaseHelper => ref.read(databaseHelperProvider);

  @override
  Future<AppSettings> build() async {
    return _loadSettings();
  }

  Future<AppSettings> _loadSettings() async {
    try {
      final String? rawDarkMode = await _databaseHelper.getSetting('dark_mode');
      final String? rawPlaybackSpeed = await _databaseHelper.getSetting(
        'playback_speed',
      );
      final String? rawSleepTimerDefault = await _databaseHelper.getSetting(
        'sleep_timer_default_minutes',
      );

      return AppSettings(
        darkMode: rawDarkMode == 'true',
        playbackSpeed:
            double.tryParse(rawPlaybackSpeed ?? '1.0') ??
            AppSettings.defaults.playbackSpeed,
        sleepTimerDefaultMinutes:
            int.tryParse(rawSleepTimerDefault ?? '30') ??
            AppSettings.defaults.sleepTimerDefaultMinutes,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> updateDarkMode(bool enabled) async {
    await _updateSetting(
      persist: () =>
          _databaseHelper.setSetting('dark_mode', enabled ? 'true' : 'false'),
      transform: (AppSettings current) => current.copyWith(darkMode: enabled),
    );
  }

  Future<void> updatePlaybackSpeed(double speed) async {
    await _updateSetting(
      persist: () => _databaseHelper.setSetting(
        'playback_speed',
        speed.toStringAsFixed(1),
      ),
      transform: (AppSettings current) =>
          current.copyWith(playbackSpeed: speed),
    );
  }

  Future<void> updateSleepTimerDefaultMinutes(int minutes) async {
    await _updateSetting(
      persist: () => _databaseHelper.setSetting(
        'sleep_timer_default_minutes',
        minutes.toString(),
      ),
      transform: (AppSettings current) =>
          current.copyWith(sleepTimerDefaultMinutes: minutes),
    );
  }

  Future<void> _updateSetting({
    required Future<void> Function() persist,
    required AppSettings Function(AppSettings current) transform,
  }) async {
    final AsyncValue<AppSettings> currentState = state;
    final AppSettings previousSettings = currentState is AsyncData<AppSettings>
        ? currentState.value
        : AppSettings.defaults;

    state = const AsyncLoading<AppSettings>();

    try {
      await persist();
      state = AsyncData<AppSettings>(transform(previousSettings));
    } catch (error, stackTrace) {
      state = AsyncError<AppSettings>(error, stackTrace);
    }
  }
}

final AsyncNotifierProvider<AppSettingsNotifier, AppSettings>
appSettingsProvider = AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

final Provider<AppSettings> resolvedAppSettingsProvider = Provider<AppSettings>(
  (Ref ref) {
    final AsyncValue<AppSettings> settings = ref.watch(appSettingsProvider);
    return settings is AsyncData<AppSettings>
        ? settings.value
        : AppSettings.defaults;
  },
);

final Provider<bool> darkModeEnabledProvider = Provider<bool>((Ref ref) {
  return ref.watch(
    resolvedAppSettingsProvider.select((AppSettings value) => value.darkMode),
  );
});

final Provider<double> defaultPlaybackSpeedProvider = Provider<double>((
  Ref ref,
) {
  return ref.watch(
    resolvedAppSettingsProvider.select(
      (AppSettings value) => value.playbackSpeed,
    ),
  );
});

final Provider<int> sleepTimerDefaultMinutesProvider = Provider<int>((Ref ref) {
  return ref.watch(
    resolvedAppSettingsProvider.select(
      (AppSettings value) => value.sleepTimerDefaultMinutes,
    ),
  );
});
