import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:game_atlas/main.dart';
import 'package:game_atlas/core/storage.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/core/demo.dart';
import 'package:game_atlas/core/companion_models.dart';
import 'package:game_atlas/core/companion_repository.dart';
import 'package:game_atlas/features/library/playthrough_dates.dart';
import 'package:game_atlas/features/settings/settings_provider.dart';
import 'package:game_atlas/shared/app_theme.dart';
import 'package:game_atlas/shared/wallet_components.dart';
import 'package:game_atlas/features/details/details_page.dart';
import 'package:game_atlas/features/journal/journal_pages.dart';
import 'package:game_atlas/features/calendar/calendar_page.dart';
import 'package:game_atlas/features/lineup/lineup_pages.dart';
import 'package:game_atlas/features/profile/statistics_page.dart';
import 'package:game_atlas/features/pick/pick_page.dart';
import 'package:game_atlas/features/pick/smart_pick_page.dart';
import 'package:game_atlas/features/settings/preferences_page.dart';
import 'package:game_atlas/features/settings/settings_page.dart';
import 'package:game_atlas/features/pricing/store_prices_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('WALLET_PREVIEWS')) {
      for (final entry in {
        'Figtree': 'assets/fonts/Figtree.ttf',
        'Bricolage Grotesque': 'assets/fonts/BricolageGrotesque.ttf',
      }.entries) {
        await (FontLoader(entry.key)..addFont(
              Future.value(
                ByteData.sublistView(File(entry.value).readAsBytesSync()),
              ),
            ))
            .load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  late Directory directory;
  late AppStorage storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wallet_redesign_');
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
      'onboardingDismissed': true,
      'setupComplete': true,
      'demo': true,
      'theme': 'dark',
      'displayName': 'Alex',
    });
    await storage.remember('deals:epic-giveaways:v2', <dynamic>[]);
    final today = DateTime.now();
    final run = GamePlaythrough(
      id: 'fixture-active',
      startDate: today.subtract(const Duration(days: 5)),
    );
    await storage.library.put(
      demoGames[0].key,
      LibraryEntry(
        game: demoGames[0],
        status: LibraryStatus.playing,
        playthroughs: [run],
        activePlaythroughId: run.id,
      ),
    );
    await storage.library.put(
      demoGames[1].key,
      LibraryEntry(game: demoGames[1], status: LibraryStatus.playing),
    );
    for (var i = 2; i < 8; i++) {
      await storage.library.put(
        demoGames[i].key,
        LibraryEntry(
          game: demoGames[i],
          favorite: i == 3,
          status: i < 5 ? LibraryStatus.completed : LibraryStatus.wantToPlay,
          playthroughs: i < 5
              ? [
                  GamePlaythrough(
                    id: 'fixture-done-$i',
                    completed: true,
                    startDate: today.subtract(Duration(days: 20 + i)),
                    endDate: today.subtract(Duration(days: 3 + i)),
                  ),
                ]
              : [],
        ),
      );
    }
    final companion = CompanionRepository(storage);
    await companion.put(
      'lineup',
      'weekend',
      const GameLineUp(
        id: 'weekend',
        title: 'A weekend of adventures',
        description: 'A fictional demo collection for visual review.',
        demo: true,
      ).copy(games: [demoGames[2], demoGames[5], demoGames[7]]).toJson(),
    );
    await companion.put(
      'journal',
      'review',
      PlaythroughEntry(
        id: 'review',
        game: demoGames[2],
        rating: 4.5,
        review: 'A quiet world worth exploring.',
        tags: ['Adventure'],
      ).toJson(),
    );
    await companion.put(
      'plan',
      'tonight',
      PlaySessionPlan(
        id: 'tonight',
        game: demoGames[5],
        scheduled: today.add(const Duration(days: 1)),
        notes: 'An evening adventure',
      ).toJson(),
    );
    // Explicit test-only quotes for the pricing screenshot. No live data or
    // credentials are used in any redesign preview.
    await storage.remember('prices:match:v1:rawg:777:fixture price game', {
      'gameID': '777',
      'external': 'Fixture price game',
    });
    await storage.remember('prices:cheapshark:v1:/games:{"id":"777"}', {
      'info': {'title': 'Fixture price game'},
      'deals': [
        {
          'storeID': '1',
          'dealID': 'fixture-steam',
          'price': '9.99',
          'retailPrice': '19.99',
        },
        {
          'storeID': '25',
          'dealID': 'fixture-epic',
          'price': '12.99',
          'retailPrice': '19.99',
        },
      ],
    });
    await storage.remember('prices:cheapshark:v1:/stores:{}', [
      {'storeID': '1', 'storeName': 'Steam', 'isActive': 1},
      {'storeID': '25', 'storeName': 'Epic Games Store', 'isActive': 1},
    ]);
    await storage.remember(
      'prices:cheapshark:v1:https://api.frankfurter.dev/v2/rate/USD/INR:{}',
      {'base': 'USD', 'quote': 'INR', 'rate': 85.0, 'date': '2026-11-04'},
    );
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('all accent choices have readable action text in both themes', () {
    const tokens = WalletTokens();
    final brightestArtwork = Color.alphaBlend(
      tokens.artworkBase.withValues(alpha: .70),
      Colors.white,
    );
    expect(
      WalletTheme.contrast(tokens.artworkText, brightestArtwork),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      WalletTheme.contrast(tokens.artworkMuted, brightestArtwork),
      greaterThanOrEqualTo(4.5),
    );
    for (final brightness in Brightness.values) {
      for (final color in accentColors.values.map(Color.new)) {
        final theme = WalletTheme.build(brightness, color),
            scheme = WalletTheme.build(brightness, color).colorScheme;
        expect(
          WalletTheme.contrast(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          WalletTheme.contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          WalletTheme.contrast(
            scheme.onSurfaceVariant,
            scheme.surfaceContainerLow,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(theme.textTheme.titleLarge?.fontFamily, 'Bricolage Grotesque');
      }
    }
  });

  testWidgets(
    'shared cards support keyboard context actions, long press and right click',
    (tester) async {
      var menus = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: WalletTheme.build(Brightness.dark, WalletTheme.defaultAccent),
          home: Scaffold(
            body: GameInteraction(
              game: demoGames[0],
              onMenu: () => menus++,
              onTap: () {},
              child: const SizedBox(
                width: 240,
                height: 80,
                child: Text('Fixture card'),
              ),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(menus, 1);
      await tester.longPress(find.text('Fixture card'));
      expect(menus, 2);
      await tester.tap(find.text('Fixture card'), buttons: 2);
      expect(menus, 3);
    },
  );

  Future<void> launch(
    WidgetTester tester,
    Size size, {
    double scale = 1,
    GlobalKey? boundary,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: GameAtlas(storage: storage),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('WALLET_PREVIEWS')) return;
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'docs/previews/redesign-$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'layout and filters use adaptive sheets and persist the existing settings',
    (tester) async {
      await launch(tester, const Size(390, 900));
      await tester.tap(find.byKey(const ValueKey('tracking-tab-1')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.byTooltip('View style')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('3 columns'));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(storage.preferences.get('libraryGridColumns'), 3);
      await tester.tap(find.text('Explore').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Filter games'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Genre'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('completion is a sheet; cancelling preserves the current run', (
    tester,
  ) async {
    await launch(tester, const Size(390, 900));
    final before = storage.library.get(demoGames[0].key)!.toJson();
    await tester.ensureVisible(find.text('Complete game').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete game').first);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(PlaythroughDatesDialog), findsOneWidget);
    expect(find.text('Start date'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(storage.library.get(demoGames[0].key)!.toJson(), before);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion disables shared search and sheet transitions', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester, const Size(390, 900));
    await tester.tap(find.byTooltip('Search my games'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher).first)
          .duration,
      Duration.zero,
    );
    expect(
      WalletTokens.motion(tester.element(find.byType(TextField).first)),
      Duration.zero,
    );
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Complete game').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete game').first);
    await tester.pumpAndSettle();
    final route =
        ModalRoute.of(tester.element(find.byType(PlaythroughDatesDialog)))
            as ModalBottomSheetRoute<dynamic>;
    expect(route.sheetAnimationStyle?.duration, Duration.zero);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(390, 900), const Size(1280, 960)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('main destinations at ${size.width}px and ${scale}x text', (
        tester,
      ) async {
        final boundary = GlobalKey();
        await launch(tester, size, scale: scale, boundary: boundary);
        final label = size.width < 900 ? 'phone' : 'desktop';
        expect(tester.takeException(), isNull);
        if (scale == 1) await capture(tester, boundary, 'my-games-$label');
        for (final tab in ['Home', 'Explore', 'Deals', 'Profile']) {
          await tester.tap(find.text(tab).last);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$tab at $size / $scale',
          );
          if (scale == 1) {
            await capture(tester, boundary, '${tab.toLowerCase()}-$label');
          }
        }
        final settings = tester
            .element(find.text('Profile').last)
            .read<SettingsProvider>();
        await tester.runAsync(() => settings.setTheme(ThemeMode.light));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) await capture(tester, boundary, 'profile-light-$label');
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final width in [390.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('supporting screens at ${width}px and ${scale}x text', (
        tester,
      ) async {
        final boundary = GlobalKey();
        await launch(
          tester,
          Size(width, 960),
          scale: scale,
          boundary: boundary,
        );
        final rootContext = tester.element(find.text('My games').last);
        final screens = <String, Widget>{
          'details': DetailsPage(initial: demoGames[0]),
          'journal': const JournalPage(),
          'journal-editor': JournalEditor(game: demoGames[5]),
          'calendar': const PlayCalendarPage(),
          'plan': PlanEditor(game: demoGames[5]),
          'collection': const LineUpDetail(id: 'weekend'),
          'lineup-editor': const LineUpEditor(),
          'statistics': const StatisticsPage(),
          'wheel': Scaffold(
            appBar: AppBar(title: const Text('Random Pick')),
            body: PickPage(onExplore: () {}),
          ),
          'smart-pick': const SmartPickPage(),
          'preferences': const PreferencesPage(),
          'settings': Scaffold(
            appBar: AppBar(title: const Text('Settings')),
            body: const SettingsPage(),
          ),
          'prices': Scaffold(
            appBar: AppBar(title: const Text('Pricing · fixture preview')),
            body: const SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: StorePricesSection(
                game: Game(
                  id: 777,
                  title: 'Fixture price game',
                  source: 'rawg',
                ),
              ),
            ),
          ),
        };
        for (final entry in screens.entries) {
          Navigator.of(
            rootContext,
          ).push<void>(MaterialPageRoute(builder: (_) => entry.value));
          await tester.pumpAndSettle();
          if (entry.key == 'prices') {
            await tester.runAsync(() async {
              await tester.tap(find.text('Stores & prices'));
              await Future<void>.delayed(const Duration(milliseconds: 100));
            });
            await tester.pumpAndSettle();
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} / $width / $scale',
          );
          if (scale == 1) {
            await capture(
              tester,
              boundary,
              '${entry.key}-${width < 900 ? 'phone' : 'desktop'}',
            );
          }
          await tester.pageBack();
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Complete game').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Complete game').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await capture(
            tester,
            boundary,
            'completion-${width < 900 ? 'phone' : 'desktop'}',
          );
        }
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
