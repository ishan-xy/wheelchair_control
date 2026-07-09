import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/main_nav.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_state.dart';

void main() => runApp(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const WheelchairApp(),
      ),
    );

class WheelchairApp extends StatelessWidget {
  const WheelchairApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VAYA Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const MainNav(),
      );
}
