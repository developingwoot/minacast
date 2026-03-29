import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:minacast/features/settings/models/app_settings.dart';
import 'package:minacast/features/settings/providers/settings_providers.dart';
import 'package:minacast/features/settings/screens/settings_screen.dart';

class FakeAppSettingsNotifier extends AppSettingsNotifier {
  FakeAppSettingsNotifier(this._initialSettings);

  final AppSettings _initialSettings;

  @override
  Future<AppSettings> build() async {
    return _initialSettings;
  }

  @override
  Future<void> updateDarkMode(bool enabled) async {
    state = AsyncData<AppSettings>(
      state.requireValue.copyWith(darkMode: enabled),
    );
  }

  @override
  Future<void> updatePlaybackSpeed(double speed) async {
    state = AsyncData<AppSettings>(
      state.requireValue.copyWith(playbackSpeed: speed),
    );
  }

  @override
  Future<void> updateSleepTimerDefaultMinutes(int minutes) async {
    state = AsyncData<AppSettings>(
      state.requireValue.copyWith(sleepTimerDefaultMinutes: minutes),
    );
  }
}

void main() {
  Widget buildTestApp(AppSettings initialSettings) {
    return ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(
          () => FakeAppSettingsNotifier(initialSettings),
        ),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  testWidgets('settings screen shows current values', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        const AppSettings(
          darkMode: true,
          playbackSpeed: 1.5,
          sleepTimerDefaultMinutes: 45,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Dark mode'), findsOneWidget);
    expect(find.text('1.5x'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);

    final SwitchListTile darkModeTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(darkModeTile.value, isTrue);
  });

  testWidgets('changing sleep timer default updates the selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp(AppSettings.defaults));
    await tester.pump();

    await tester.tap(find.text('30 min').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('60 min').last);
    await tester.pumpAndSettle();

    expect(find.text('60 min'), findsWidgets);
  });
}
