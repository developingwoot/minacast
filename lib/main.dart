import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/screens/home_screen.dart';
import 'features/settings/screens/settings_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Color(0xFF1DB9FF);
    const Color backgroundColor = Color(0xFF111318);
    const Color surfaceColor = Color(0xFF1E2028);
    const Color textColor = Color(0xFFE4E6EF);

    const ColorScheme colorScheme = ColorScheme.dark(
      primary: accentColor,
      secondary: accentColor,
      surface: surfaceColor,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: textColor,
      outline: Color(0xFF9094A5),
    );

    return MaterialApp(
      title: 'Minacast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
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
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surfaceColor,
          selectedItemColor: accentColor,
          unselectedItemColor: Color(0xFF9094A5),
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _tabs = <Widget>[HomeScreen(), SettingsScreen()];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _tabs),
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
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
