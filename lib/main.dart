import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'background/background_sync_task.dart';
import 'data/database_helper.dart';
import 'features/home/providers/feed_provider.dart';
import 'features/home/screens/home_screen.dart';
import 'features/home/services/on_open_download_service.dart';
import 'features/playback/providers/playback_providers.dart';
import 'features/playback/services/playback_persistence_coordinator.dart';
import 'features/playback/services/podcast_audio_handler.dart';
import 'features/playback/widgets/mini_player.dart';
import 'features/settings/providers/settings_providers.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/subscriptions/screens/subscriptions_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register the WorkManager periodic sync task. ExistingWorkPolicy.keep means
  // re-registering on every launch does not reset the 24-hour countdown.
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(
    kBackgroundSyncTaskName,
    kBackgroundSyncTaskName,
    frequency: const Duration(hours: 24),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );

  // Pre-create the notification channel in the main isolate so it exists
  // before the background isolate ever tries to send a notification.
  // Android 8.0+ requires the channel to be created before show() is called.
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  await notificationsPlugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          kNotificationChannelId,
          kNotificationChannelName,
          description: 'New episode alerts',
          importance: Importance.defaultImportance,
        ),
      );

  final PodcastAudioHandler audioHandler = await AudioService.init(
    builder: () => PodcastAudioHandler(databaseHelper: DatabaseHelper.instance),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.developingwoot.minacast.playback',
      androidNotificationChannelName: 'Minacast Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  PlaybackPersistenceCoordinator? _coordinator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _coordinator = ref.read(playbackPersistenceCoordinatorProvider);
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final PlaybackPersistenceCoordinator? coordinator = _coordinator;
    if (coordinator == null) {
      return;
    }

    unawaited(coordinator.handleAppLifecycleStateChanged(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF1DB9FF);
    final bool darkModeEnabled = ref.watch(darkModeEnabledProvider);

    return MaterialApp(
      title: 'Minacast',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(accentColor),
      darkTheme: _buildDarkTheme(accentColor),
      themeMode: darkModeEnabled ? ThemeMode.dark : ThemeMode.light,
      home: const AppShell(),
    );
  }

  ThemeData _buildLightTheme(Color accentColor) {
    const Color backgroundColor = Color(0xFFF4F7FB);
    const Color surfaceColor = Colors.white;
    const Color textColor = Color(0xFF18202B);
    const Color mutedColor = Color(0xFF677285);

    final ColorScheme colorScheme = ColorScheme.light(
      primary: accentColor,
      secondary: accentColor,
      surface: surfaceColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textColor,
      outline: mutedColor,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: surfaceColor,
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: accentColor,
        unselectedItemColor: mutedColor,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  ThemeData _buildDarkTheme(Color accentColor) {
    const Color backgroundColor = Color(0xFF111318);
    const Color surfaceColor = Color(0xFF1E2028);
    const Color textColor = Color(0xFFE4E6EF);

    final ColorScheme colorScheme = ColorScheme.dark(
      primary: accentColor,
      secondary: accentColor,
      surface: surfaceColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: textColor,
      outline: Color(0xFF9094A5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: surfaceColor,
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: accentColor,
        unselectedItemColor: Color(0xFF9094A5),
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _tabs = <Widget>[
    HomeScreen(),
    SubscriptionsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _triggerOnOpenDownload();
  }

  void _triggerOnOpenDownload() {
    OnOpenDownloadService(databaseHelper: DatabaseHelper.instance)
        .run()
        .then((_) {
          if (mounted) ref.invalidate(feedProvider);
        });
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget player = ref.watch(miniPlayerVisibleProvider)
        ? const MiniPlayer()
        : const SizedBox.shrink();

    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _tabs),
          ),
          player,
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onDestinationSelected,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.podcasts_outlined),
            activeIcon: Icon(Icons.podcasts),
            label: 'Podcasts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
