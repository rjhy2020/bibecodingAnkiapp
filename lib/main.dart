import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/services/anki_native_api.dart';
import 'src/services/deep_nuance_cache.dart';
import 'src/services/gemini_client.dart';
import 'src/state/daily_deck_progress_controller.dart';
import 'src/state/home_controller.dart';
import 'src/state/llm_deck_config_controller.dart';
import 'src/state/study_settings_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => const AnkiNativeApi()),
        Provider(
          create: (_) => GeminiClient(),
          dispose: (_, client) => client.dispose(),
        ),
        Provider(create: (_) => DeepNuanceCache()),
        ChangeNotifierProvider(
          create: (context) => HomeController(context.read<AnkiNativeApi>()),
        ),
        ChangeNotifierProvider(create: (_) => DailyDeckProgressController()),
        ChangeNotifierProvider(create: (_) => StudySettingsController()),
        ChangeNotifierProvider(create: (_) => LlmDeckConfigController()),
      ],
      child: const EnglishAnkiApp(),
    ),
  );
}
