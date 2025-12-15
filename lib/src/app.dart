import 'package:flutter/material.dart';

import 'ui/home_screen.dart';

class EnglishAnkiApp extends StatelessWidget {
  const EnglishAnkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    );

    return MaterialApp(
      title: 'English Anki Preview',
      theme: theme,
      home: const HomeScreen(),
    );
  }
}

