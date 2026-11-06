import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_service.dart';
import 'core/image_cache_service.dart';
import 'core/game_repository.dart';
import 'core/federated_game_repository.dart';
import 'core/freetogame_service.dart';
import 'core/catalog_identity.dart';
import 'core/storage.dart';
import 'core/companion_repository.dart';
import 'features/companion/companion_providers.dart';
import 'features/explore/search_provider.dart';
import 'features/home/home_provider.dart';
import 'features/library/library_provider.dart';
import 'features/settings/settings_provider.dart';
import 'shared/app_shell.dart';
import 'shared/app_theme.dart';
import 'features/deals/deals_service.dart';
import 'features/deals/deals_repository.dart';
import 'features/deals/deals_provider.dart';
import 'features/deals/deals_catalog_provider.dart';
import 'features/pricing/pricing_service.dart';
import 'features/pricing/pricing_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WalletTheme.registerFontLicenses();
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
      ChangeNotifierProvider(create: (_) => CatalogIdentity(storage)),
      Provider(
        create: (_) => FreeToGameRepository(storage, FreeToGameService()),
        dispose: (_, repository) => repository.dispose(),
      ),
      Provider(
        create: (_) => DealsService(),
        dispose: (_, service) => service.dispose(),
      ),
      Provider(
        create: (context) =>
            DealsRepository(storage, context.read<DealsService>()),
      ),
      ChangeNotifierProvider(
        create: (context) => DealsProvider(context.read<DealsRepository>()),
      ),
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
        create: (context) => JournalProvider(
          context.read<CompanionRepository>(),
          identities: context.read<CatalogIdentity>(),
        ),
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
        create: (context) => DiscoveryPreferencesProvider(
          context.read<CompanionRepository>(),
          identities: context.read<CatalogIdentity>(),
        ),
      ),
      ChangeNotifierProvider(create: (_) => WheelProvider()),
      Provider<GameRepository>(
        create: (context) => FederatedGameRepository(
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
          context.read<FreeToGameRepository>(),
          context.read<CatalogIdentity>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) =>
            DealsCatalogProvider(context.read<GameRepository>()),
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
          identities: context.read<CatalogIdentity>(),
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
  ThemeData theme(
    Brightness brightness,
    Color accentColor, {
    bool amoled = false,
  }) => WalletTheme.build(brightness, accentColor, amoled: amoled);

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
      amoled: context.select<SettingsProvider, bool>((p) => p.amoled),
    ),
    themeMode: context.select<SettingsProvider, ThemeMode>((p) => p.theme),
    home: const AppShell(),
  );
}
