import 'package:englishankiapp/src/app.dart';
import 'package:englishankiapp/src/services/anki_native_api.dart';
import 'package:englishankiapp/src/state/home_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('anki_provider');

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getStatus':
          return {
            'installed': false,
            'providerVisible': false,
            'providerAccessible': false,
            'lastErrorCode': 'ANKI_NOT_INSTALLED',
            'lastErrorMessage': 'mock',
          };
        case 'getTodayNewCards':
          return <dynamic>[];
        case 'openPlayStore':
        case 'openAnkiDroid':
          return true;
        default:
          throw PlatformException(code: 'not_implemented');
      }
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Home renders without crashing', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => const AnkiNativeApi()),
          ChangeNotifierProvider(
            create: (context) => HomeController(context.read<AnkiNativeApi>()),
          ),
        ],
        child: const EnglishAnkiApp(),
      ),
    );

    await tester.pump(); // post-frame callback
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('학습 시작'), findsOneWidget);
    expect(find.textContaining('AnkiDroid'), findsWidgets);
  });
}

