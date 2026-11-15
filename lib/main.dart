import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'presentation/home/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ElektroshchitApp()));
}

class ElektroshchitApp extends StatelessWidget {
  const ElektroshchitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Электрощит',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
