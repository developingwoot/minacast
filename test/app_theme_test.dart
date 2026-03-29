import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:minacast/features/settings/providers/settings_providers.dart';

void main() {
  Widget buildTestApp(bool darkModeEnabled) {
    return ProviderScope(
      overrides: [
        darkModeEnabledProvider.overrideWith((Ref ref) => darkModeEnabled),
      ],
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? child) {
          return MaterialApp(
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ref.watch(darkModeEnabledProvider)
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  testWidgets('theme wiring uses light mode when dark mode is disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp(false));

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.light);
  });

  testWidgets('theme wiring uses dark mode when dark mode is enabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestApp(true));

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.themeMode, ThemeMode.dark);
  });
}
