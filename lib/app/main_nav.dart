import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/widgets/emergency_assistance_sheet.dart';
import '../providers/app_state.dart';
import '../screens/control_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => MainNavState();
}

class MainNavState extends State<MainNav> {
  int _index = 0;
  StreamSubscription<EmergencySignalSource>? _emergencySignalSub;
  bool _presentingEmergencySheet = false;

  @override
  void initState() {
    super.initState();
    _emergencySignalSub =
        context.read<AppState>().emergencySignalStream.listen(_showEmergency);
  }

  @override
  void dispose() {
    _emergencySignalSub?.cancel();
    super.dispose();
  }

  static MainNavState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainNavState>();

  static const _screens = [
    ControlScreen(),
    HomeScreen(),
    SettingsScreen(),
  ];

  void setIndex(int value) {
    if (value == _index) return;
    setState(() => _index = value);
  }

  void _showEmergency(EmergencySignalSource source) {
    if (!mounted || _presentingEmergencySheet) return;
    _presentingEmergencySheet = true;
    unawaited(
        showEmergencyAssistanceSheet(context, source: source).whenComplete(
      () => _presentingEmergencySheet = false,
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: setIndex,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.open_with_rounded),
              selectedIcon: Icon(Icons.open_with_rounded),
              label: 'Control',
            ),
            NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon: Icon(Icons.monitor_heart_rounded),
              label: 'Status',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      );
}
