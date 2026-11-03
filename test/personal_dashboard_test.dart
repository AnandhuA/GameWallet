import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:game_atlas/core/api_service.dart';
import 'package:game_atlas/core/companion_models.dart';
import 'package:game_atlas/core/game_repository.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/core/storage.dart';
import 'package:game_atlas/features/library/dashboard_model.dart';
import 'package:game_atlas/features/settings/settings_provider.dart';
import 'package:game_atlas/features/settings/preferences_page.dart';
import 'package:game_atlas/features/explore/search_provider.dart';
import 'package:game_atlas/features/home/home_provider.dart';
import 'package:game_atlas/main.dart';

class PreferenceCatalog extends GameRepository {
  bool fail = false;
  final platforms = <String?>[];
  final tokens = <CancelToken?>[];
  PreferenceCatalog(AppStorage storage) : super(storage, ApiService());
  @override
  Future<CatalogFilters> filters(bool demo, {bool forceRefresh = false}) async {
    if (fail) throw const ApiFailure('Offline fixture');
    return const CatalogFilters(
      {'action': 'Action', 'rpg': 'RPG'},
      {
        '4': 'PC',
        '18': 'PlayStation 4',
        '7': 'Nintendo Switch',
        '21': 'Android',
        '3': 'iOS',
        '1': 'Xbox One',
      },
    );
  }

  @override
  Future<CatalogResult> games({
    required bool demo,
    String feed = 'search',
    String query = '',
    String? genre,
    String? platform,
    int? year,
    String sort = 'popular',
    int page = 0,
    CancelToken? cancel,
    bool forceRefresh = false,
  }) async {
    platforms.add(platform);
    tokens.add(cancel);
    return CatalogResult([]);
  }
}

void main() {
  late Directory directory;
  late AppStorage storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('personal_dashboard');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LibraryEntryAdapter());
    }
    storage = AppStorage(
      await Hive.openBox<LibraryEntry>('library'),
      await Hive.openBox('preferences'),
      await Hive.openBox('cache'),
      personal: await Hive.openBox('personal'),
    );
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'Fresh setup is requested once; existing preferences and personal records bypass onboarding',
    () async {
      await storage.prepareOnboarding(fresh: true);
      final settings = SettingsProvider(storage, PreferenceCatalog(storage));
      expect(settings.needsOnboarding, true);
      await settings.dismissOnboarding();
      await storage.prepareOnboarding(fresh: true);
      expect(settings.needsOnboarding, false);
      expect(settings.platforms, isEmpty);
      await storage.preferences.delete('onboardingDismissed');
      await storage.preferences.put('platforms', ['4', '18']);
      await storage.prepareOnboarding(fresh: false);
      expect(storage.preferences.get('platforms:rawg'), ['4', '18']);
      await storage.prepareOnboarding(fresh: false);
      expect(storage.preferences.get('platforms:rawg'), ['4', '18']);
      expect(settings.needsOnboarding, false);
      await storage.preferences.delete('onboardingDismissed');
      await storage.library.put(
        'rawg:1',
        LibraryEntry(
          game: const Game(id: 1, title: 'Existing', source: 'rawg'),
        ),
      );
      await storage.prepareOnboarding(fresh: true);
      expect(settings.needsOnboarding, false);
    },
  );

  test(
    'Saved preferences retain both sources and match any selected platform',
    () async {
      final settings = SettingsProvider(storage, PreferenceCatalog(storage));
      await settings.saveSetup('Player', ['Action'], ['PC']);
      expect(settings.setupComplete, true);
      await settings.setDemo(false);
      expect(settings.platforms, isEmpty);
      await settings.saveSetup('Player', ['RPG'], ['4', '18']);
      final filters = await settings.loadPlatforms();
      expect(
        settings.matchesPlatforms(
          const Game(id: 1, title: 'Console', platforms: ['PlayStation 4']),
          filters,
        ),
        true,
      );
      expect(
        settings.matchesPlatforms(
          const Game(id: 2, title: 'Mobile', platforms: ['Android']),
          filters,
        ),
        false,
      );
      final reopened = SettingsProvider(storage, PreferenceCatalog(storage));
      expect(reopened.platforms, ['4', '18']);
      await settings.setDemo(true);
      expect(settings.platforms, ['PC']);
    },
  );

  test(
    'All preferred platforms reach discovery; Explore override does not edit preferences',
    () async {
      final catalog = PreferenceCatalog(storage);
      final home = HomeProvider(catalog);
      await home.load(false, ['4', '18']);
      expect(catalog.platforms, everyElement('4,18'));
      final old = catalog.tokens.first!;
      await home.load(false, ['21']);
      expect(old.isCancelled, true);
      final search = SearchProvider(catalog);
      search.configure(false, ['4', '18']);
      await Future<void>.delayed(Duration.zero);
      expect(search.platform, SearchProvider.myPlatforms);
      expect(catalog.platforms.last, '4,18');
      search.apply(platformValue: '21');
      await Future<void>.delayed(Duration.zero);
      expect(catalog.platforms.last, '21');
      expect(search.preferredPlatforms, ['4', '18']);
      search.apply();
      await Future<void>.delayed(Duration.zero);
      expect(catalog.platforms.last, null);
      search.dispose();
      home.dispose();
    },
  );

  test(
    'Demo multi-platform filtering uses OR and does not restrict unfiltered browsing',
    () async {
      final repo = GameRepository(storage, ApiService());
      final both = await repo.games(demo: true, platform: 'PC,Android');
      expect(both.games.length, 12);
      final mobile = await repo.games(demo: true, platform: 'Android');
      expect(mobile.games.length, 4);
    },
  );

  test('Dashboard excludes undated finishes and orders pending plans', () {
    final now = DateTime(2026, 10, 31, 12);
    const current = Game(id: 1, title: 'Current');
    const saved = Game(id: 2, title: 'Saved');
    const legacy = Game(id: 3, title: 'Legacy');
    final entries = [
      LibraryEntry(game: saved, status: LibraryStatus.wantToPlay, updated: now),
      LibraryEntry(
        game: current,
        status: LibraryStatus.playing,
        updated: now.subtract(const Duration(days: 1)),
      ),
      LibraryEntry(
        game: legacy,
        status: LibraryStatus.completed,
        completedRuns: 4,
      ),
      LibraryEntry(
        game: const Game(id: 4, title: 'Dated'),
        status: LibraryStatus.completed,
        playthroughs: [
          GamePlaythrough(id: 'run', completed: true, endDate: now),
        ],
      ),
    ];
    final sessions = [
      PlaySessionPlan(
        id: 'later',
        game: saved,
        scheduled: now.add(const Duration(days: 2)),
      ),
      PlaySessionPlan(
        id: 'soon',
        game: saved,
        scheduled: now.add(const Duration(days: 1)),
      ),
      PlaySessionPlan(id: 'done', game: saved, scheduled: now, completed: true),
      PlaySessionPlan(
        id: 'past',
        game: saved,
        scheduled: now.subtract(const Duration(days: 1)),
      ),
    ];
    final model = DashboardModel(entries, sessions, now);
    expect(model.plans.map((p) => p.id), ['soon', 'later']);
    expect(model.finishes.map((r) => r.$1.title), ['Dated']);
    final empty = DashboardModel([], [], now);
    expect(empty.plans, isEmpty);
    expect(empty.finishes, isEmpty);
  });

  Future<void> openEditor(
    WidgetTester tester,
    SettingsProvider settings, {
    bool onboarding = true,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PreferencesPage(onboarding: onboarding),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Questionnaire saves only on Finish and Back retains local selections',
    (tester) async {
      final settings = SettingsProvider(storage, PreferenceCatalog(storage));
      await openEditor(tester, settings);
      await tester.enterText(find.byType(TextField), 'Alex');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'RPG'));
      expect(settings.genres, isEmpty);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'PC'));
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'RPG'))
            .selected,
        true,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'PC'))
            .selected,
        true,
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Finish'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(settings.displayName, 'Alex');
      expect(settings.genres, ['RPG']);
      expect(settings.platforms, ['4']);
      expect(find.text('Open'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Alex'), findsOneWidget);
    },
  );

  testWidgets(
    'Offline onboarding can retry or skip without saving draft answers',
    (tester) async {
      final catalog = PreferenceCatalog(storage)..fail = true;
      final settings = SettingsProvider(storage, catalog);
      await openEditor(tester, settings);
      await tester.enterText(find.byType(TextField), 'Draft');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Preferences unavailable'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Skip for now'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(settings.displayName, 'Player');
      expect(settings.needsOnboarding, false);
      expect(find.text('Open'), findsOneWidget);
    },
  );

  testWidgets(
    'App opens on My games and presents onboarding once on a fresh install',
    (tester) async {
      await tester.runAsync(() => storage.prepareOnboarding(fresh: true));
      await tester.pumpWidget(GameAtlas(storage: storage));
      await tester.pumpAndSettle();
      expect(find.text('What should we call you?'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text('Skip for now'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(find.textContaining('Your gaming space'), findsOneWidget);
      expect(find.text('Ready for your next adventure?'), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2,
      );
    },
  );
  testWidgets(
    'Personal dashboard remains usable at phone and desktop sizes with enlarged text',
    (tester) async {
      await tester.runAsync(() async {
        await storage.library.put(
          'demo:1',
          LibraryEntry(
            game: const Game(
              id: 1,
              title: 'A long current adventure title',
              demo: true,
            ),
            status: LibraryStatus.playing,
            playthroughs: [
              GamePlaythrough(id: 'active', startDate: DateTime.now()),
            ],
            activePlaythroughId: 'active',
          ),
        );
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;

      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(GameAtlas(storage: storage));
      await tester.pumpAndSettle();
      expect(find.text('PICK UP WHERE YOU LEFT OFF'), findsNothing);
      expect(find.text('A long current adventure title'), findsOneWidget);
      expect(find.text('Complete game'), findsWidgets);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Header search expands, focuses, filters and collapses with Escape or close',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(GameAtlas(storage: storage));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-games-search-field')), findsNothing);
      await tester.tap(find.byTooltip('Search my games'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byKey(const ValueKey('my-games-search-field')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('my-games-search-field')),
      );
      expect(field.focusNode!.hasFocus, true);
      await tester.enterText(
        find.byKey(const ValueKey('my-games-search-field')),
        'No matching fixture',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching games'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-games-search-field')), findsNothing);
      expect(find.text('No matching games'), findsNothing);
      expect(find.byTooltip('Search my games'), findsOneWidget);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Search my games'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close search'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-games-search-field')), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Playing exposes editable start dates and dense Played grids show only known durations',
    (tester) async {
      await tester.runAsync(() async {
        await storage.preferences.put('libraryGridColumns', 5);
        await storage.library.put(
          'demo:501',
          LibraryEntry(
            game: const Game(id: 501, title: 'Current run', demo: true),
            status: LibraryStatus.playing,
            playthroughs: [
              GamePlaythrough(id: 'active', startDate: DateTime.now()),
            ],
            activePlaythroughId: 'active',
          ),
        );
        await storage.library.put(
          'demo:502',
          LibraryEntry(
            game: const Game(id: 502, title: 'Known finish', demo: true),
            status: LibraryStatus.completed,
            completedRuns: 1,
            playthroughs: [
              GamePlaythrough(
                id: 'done',
                completed: true,
                startDate: DateTime(2020, 1, 1),
                endDate: DateTime(2020, 1, 3),
              ),
            ],
          ),
        );
        await storage.library.put(
          'demo:503',
          LibraryEntry(
            game: const Game(id: 503, title: 'Unknown finish', demo: true),
            status: LibraryStatus.completed,
            completedRuns: 1,
          ),
        );
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(GameAtlas(storage: storage));
      await tester.pumpAndSettle();
      expect(find.text('Day 1'), findsOneWidget);
      await tester.ensureVisible(find.textContaining('Started '));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Started '));
      await tester.pumpAndSettle();
      expect(find.text('Edit dates'), findsOneWidget);
      expect(find.text('Start date'), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('tracking-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tracking-tab-1')));
      await tester.pumpAndSettle();
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('Dates not recorded'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
