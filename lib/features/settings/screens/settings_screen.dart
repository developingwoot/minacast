import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../providers/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final AsyncValue<AppSettings> settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings.when(
        data: (AppSettings value) => _SettingsContent(settings: value),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.error_outline, size: 56, color: colors.outline),
                const SizedBox(height: 16),
                Text(
                  'Settings could not be loaded.',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please reopen the app and try again.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.outline),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsContent extends ConsumerWidget {
  const _SettingsContent({required this.settings});

  final AppSettings settings;

  static const List<double> _speedOptions = <double>[0.5, 1.0, 1.5, 2.0];
  static const List<int> _sleepTimerOptions = <int>[15, 30, 45, 60];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettingsNotifier notifier = ref.read(appSettingsProvider.notifier);
    final bool isUpdating = ref.watch(appSettingsProvider).isLoading;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: SwitchListTile(
            title: const Text('Dark mode'),
            subtitle: const Text('Switch the entire app theme instantly.'),
            value: settings.darkMode,
            onChanged: isUpdating
                ? null
                : (bool enabled) async {
                    await notifier.updateDarkMode(enabled);
                  },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('Default playback speed'),
            subtitle: const Text('Used for new episodes when playback starts.'),
            trailing: DropdownButton<double>(
              value: settings.playbackSpeed,
              onChanged: isUpdating
                  ? null
                  : (double? value) async {
                      if (value == null) {
                        return;
                      }

                      await notifier.updatePlaybackSpeed(value);
                    },
              items: _speedOptions.map((double option) {
                return DropdownMenuItem<double>(
                  value: option,
                  child: Text('${option.toStringAsFixed(1)}x'),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('Sleep timer default'),
            subtitle: const Text('Preselected when you start the sleep timer.'),
            trailing: DropdownButton<int>(
              value: settings.sleepTimerDefaultMinutes,
              onChanged: isUpdating
                  ? null
                  : (int? value) async {
                      if (value == null) {
                        return;
                      }

                      await notifier.updateSleepTimerDefaultMinutes(value);
                    },
              items: _sleepTimerOptions.map((int option) {
                return DropdownMenuItem<int>(
                  value: option,
                  child: Text('$option min'),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
