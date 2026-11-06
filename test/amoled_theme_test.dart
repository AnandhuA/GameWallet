import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:game_atlas/core/api_service.dart';
import 'package:game_atlas/core/game_repository.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/core/storage.dart';
import 'package:game_atlas/features/settings/settings_page.dart';
import 'package:game_atlas/features/settings/settings_provider.dart';
import 'package:game_atlas/main.dart';
import 'package:game_atlas/shared/app_theme.dart';

void main() {
  late Directory directory;
  late AppStorage storage;
  SettingsProvider settings() =>
      SettingsProvider(storage, GameRepository(storage, ApiService()));
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wallet_amoled_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LibraryEntryAdapter());
    }
    storage = AppStorage(
      await Hive.openBox<LibraryEntry>('library'),
      await Hive.openBox('preferences'),
      await Hive.openBox('cache'),
      personal: await Hive.openBox('personal'),
      images: await Hive.openBox('images'),
    );
    await storage.preferences.putAll({
      'demo': true,
      'onboardingDismissed': true,
      'setupComplete': true,
    });
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('legacy theme preferences default to standard themes', () async {
    final provider = settings();
    expect(provider.amoled, false);
    expect(provider.theme, ThemeMode.dark);
    for (final mode in ThemeMode.values) {
      await storage.preferences.put('theme', mode.name);
      expect(provider.theme, mode);
      expect(provider.amoled, false);
    }
    provider.dispose();
  });

  test(
    'AMOLED persists after reopening and preserves accent and personal data',
    () async {
      final provider = settings();
      await provider.setAccentColor(0xFF8B5CF6);
      const game = Game(id: 9, title: 'Personal fixture', source: 'rawg');
      await storage.library.put(
        game.key,
        LibraryEntry(game: game, notes: 'Keep my notes', favorite: true),
      );
      await provider.setAmoled(true);
      expect(provider.theme, ThemeMode.dark);
      expect(provider.amoled, true);
      provider.dispose();
      await storage.preferences.close();
      storage = AppStorage(
        storage.library,
        await Hive.openBox('preferences'),
        storage.cache,
        personal: storage.personal,
        images: storage.images,
      );
      final reopened = settings();
      expect(reopened.amoled, true);
      expect(reopened.accentColor.toARGB32(), 0xFF8B5CF6);
      expect(storage.library.get(game.key)?.notes, 'Keep my notes');
      expect(storage.library.get(game.key)?.favorite, true);
      await storage.clearCache();
      expect(reopened.amoled, true);
      reopened.dispose();
    },
  );

  test(
    'all standard choices disable AMOLED and remain mutually exclusive',
    () async {
      final provider = settings();
      for (final mode in ThemeMode.values) {
        await provider.setAmoled(true);
        expect(provider.theme, ThemeMode.dark);
        await provider.setTheme(mode);
        expect(provider.amoled, false);
        expect(provider.theme, mode);
        expect(storage.preferences.get('amoled'), false);
      }
      await provider.setAmoled(true);
      await provider.setAmoled(false);
      expect(provider.theme, ThemeMode.dark);
      expect(provider.amoled, false);
      provider.dispose();
    },
  );

  test(
    'pure black backgrounds retain raised surfaces and readable accents',
    () {
      for (final seed in accentColors.values.map(Color.new)) {
        final normal = WalletTheme.build(Brightness.dark, seed);
        final black = WalletTheme.build(Brightness.dark, seed, amoled: true);
        expect(black.scaffoldBackgroundColor, Colors.black);
        expect(black.appBarTheme.backgroundColor, Colors.black);
        expect(black.navigationBarTheme.backgroundColor, Colors.black);
        expect(black.navigationRailTheme.backgroundColor, Colors.black);
        expect(black.colorScheme.surface, Colors.black);
        expect(black.cardTheme.color, const Color(0xFF080808));
        expect(black.bottomSheetTheme.backgroundColor, const Color(0xFF080808));
        expect(black.inputDecorationTheme.fillColor, const Color(0xFF080808));
        expect(black.colorScheme.primary, normal.colorScheme.primary);
        expect(
          WalletTheme.contrast(
            black.colorScheme.onSurface,
            black.colorScheme.surface,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          WalletTheme.contrast(
            black.colorScheme.onSurfaceVariant,
            black.colorScheme.surfaceContainerLow,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          WalletTheme.contrast(
            black.colorScheme.primary,
            black.colorScheme.onPrimary,
          ),
          greaterThanOrEqualTo(4.5),
        );
      }
      expect(
        WalletTheme.build(
          Brightness.light,
          WalletTheme.defaultAccent,
          amoled: true,
        ).scaffoldBackgroundColor,
        WalletTheme.build(
          Brightness.light,
          WalletTheme.defaultAccent,
        ).scaffoldBackgroundColor,
      );
    },
  );

  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'appearance selection updates immediately at width $width and enlarged text',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 960);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue =
            Brightness.light;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await tester.pumpWidget(GameAtlas(storage: storage));
        await tester.pumpAndSettle();
        final context = tester.element(find.text('My games').last);
        final provider = context.read<SettingsProvider>();
        final accent = provider.accentColor;
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Settings')),
              body: const SettingsPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Pure black'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        Future<void> choose(String label) async {
          await tester.ensureVisible(find.widgetWithText(ChoiceChip, label));
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            await tester.tap(find.widgetWithText(ChoiceChip, label));
            await Future<void>.delayed(const Duration(milliseconds: 30));
          });
          await tester.pumpAndSettle();
        }

        await choose('Pure black');
        expect(provider.amoled, true);
        expect(provider.accentColor, accent);
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Pure black'))
              .selected,
          true,
        );
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'dark'))
              .selected,
          false,
        );
        expect(
          Theme.of(
            tester.element(find.text('Pure black')),
          ).scaffoldBackgroundColor,
          Colors.black,
        );
        await choose('light');
        expect(provider.amoled, false);
        expect(
          Theme.of(tester.element(find.text('Pure black'))).brightness,
          Brightness.light,
        );
        await choose('Pure black');
        await choose('system');
        expect(provider.amoled, false);
        expect(
          Theme.of(tester.element(find.text('Pure black'))).brightness,
          Brightness.light,
        );
        await choose('Pure black');
        await choose('dark');
        expect(
          Theme.of(
            tester.element(find.text('Pure black')),
          ).scaffoldBackgroundColor,
          const Color(0xFF0F1016),
        );
        expect(provider.accentColor, accent);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
