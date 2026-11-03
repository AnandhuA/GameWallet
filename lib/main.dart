import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_service.dart';
import 'core/image_cache_service.dart';
import 'core/game_repository.dart';
import 'core/storage.dart';
import 'core/companion_repository.dart';
import 'features/companion/companion_providers.dart';
import 'features/explore/search_provider.dart';
import 'features/home/home_provider.dart';
import 'features/library/library_provider.dart';
import 'features/settings/settings_provider.dart';
import 'shared/app_shell.dart';
import 'features/pricing/pricing_service.dart';
import 'features/pricing/pricing_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final storage = await AppStorage.open();
    await CompanionRepository(storage).prepare();
    runApp(GameAtlas(storage: storage));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Game Wallet could not open local storage. Close other copies and restart the app. Your saved data has not been deleted.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GameAtlas extends StatelessWidget {
  final AppStorage storage;
  const GameAtlas({super.key, required this.storage});
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      Provider(
        create: (_) => PricingService(),
        dispose: (_, service) => service.dispose(),
      ),
      Provider(
        create: (context) =>
            PricingRepository(storage, context.read<PricingService>()),
      ),
      ChangeNotifierProvider(create: (_) => ImageCacheService(storage.images)),
      Provider(create: (_) => CompanionRepository(storage)),
      ChangeNotifierProvider(
        create: (context) =>
            JournalProvider(context.read<CompanionRepository>()),
      ),
      ChangeNotifierProvider(
        create: (context) =>
            LineUpProvider(context.read<CompanionRepository>()),
      ),
      ChangeNotifierProvider(
        create: (context) =>
            CalendarProvider(context.read<CompanionRepository>()),
      ),
      ChangeNotifierProvider(
        create: (context) =>
            DiscoveryPreferencesProvider(context.read<CompanionRepository>()),
      ),
      ChangeNotifierProvider(create: (_) => WheelProvider()),
      Provider(
        create: (_) => GameRepository(
          storage,
          ApiService(
            apiKey: () =>
                storage.preferences.get(
                      'rawgApiKey',
                      defaultValue: const String.fromEnvironment(
                        'RAWG_API_KEY',
                      ),
                    )
                    as String,
          ),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) =>
            SettingsProvider(storage, context.read<GameRepository>()),
      ),
      ChangeNotifierProvider(
        create: (context) => LibraryProvider(
          storage,
          imageCache: context.read<ImageCacheService>(),
          observeClock: true,
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => HomeProvider(context.read<GameRepository>()),
      ),
      ChangeNotifierProvider(
        create: (context) => SearchProvider(context.read<GameRepository>()),
      ),
    ],
    child: const AtlasApp(),
  );
}

class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key});
  ThemeData theme(Brightness brightness, Color accentColor) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: brightness,
      surface: dark ? const Color(0xFF080B0D) : const Color(0xFFF5F8F9),
      primary: dark ? accentColor : null,
      secondaryContainer: Color.lerp(
        dark ? const Color(0xFF151A20) : Colors.white,
        accentColor,
        dark ? .3 : .2,
      ),
      onSecondaryContainer: dark ? Colors.white : Colors.black87,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF171D1F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 76,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: .4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Game Wallet',
    debugShowCheckedModeBanner: false,
    theme: theme(
      Brightness.light,
      context.watch<SettingsProvider>().accentColor,
    ),
    darkTheme: theme(
      Brightness.dark,
      context.watch<SettingsProvider>().accentColor,
    ),
    themeMode: context.select<SettingsProvider, ThemeMode>((p) => p.theme),
    home: const AppShell(),
  );
}
