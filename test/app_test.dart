import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:game_atlas/core/api_service.dart';
import 'package:game_atlas/core/game_repository.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/core/storage.dart';
import 'package:game_atlas/features/pricing/pricing_repository.dart';
import 'package:game_atlas/features/pricing/pricing_service.dart';
import 'package:game_atlas/features/explore/search_provider.dart';
import 'package:game_atlas/features/library/library_provider.dart';
import 'package:game_atlas/main.dart';
import 'package:game_atlas/features/details/details_page.dart';
import 'package:game_atlas/shared/widgets.dart';
import 'package:game_atlas/features/settings/settings_provider.dart';
import 'package:game_atlas/core/demo.dart';
import 'package:game_atlas/core/companion_repository.dart';
import 'package:game_atlas/features/companion/companion_providers.dart';

class FailingRepository extends GameRepository {
  FailingRepository(AppStorage storage) : super(storage, ApiService());
  @override
  Future<(Game, bool)> detail(
    int id,
    bool demo, {
    CancelToken? cancel,
    bool forceRefresh = false,
  }) async => throw const ApiFailure('Offline fixture');
}

class ControlledRepository extends GameRepository {
  ControlledRepository(AppStorage storage) : super(storage, ApiService());
  final calls = <String>[];
  final requests = <Completer<CatalogResult>>[];
  final tokens = <CancelToken?>[];
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
  }) {
    calls.add('$query:$page:$genre');
    tokens.add(cancel);
    final request = Completer<CatalogResult>();
    requests.add(request);
    return request.future;
  }
}

class FixtureAdapter implements HttpClientAdapter {
  bool fail = false, malformed = false;
  RequestOptions? lastRequest;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      fail
          ? '{"message":"Service unavailable"}'
          : malformed
          ? '[]'
          : '{"results":[{"id":42,"name":"Fixture","rating":4.5,"ratings_count":12,"background_image":"https://example.com/cover.jpg"}],"next":null}',
      fail ? 503 : 200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory directory;
  late AppStorage storage;
  var time = DateTime.utc(2026, 1, 1);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('atlas_test');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LibraryEntryAdapter());
    }
    storage = AppStorage(
      await Hive.openBox<LibraryEntry>('library'),
      await Hive.openBox('preferences'),
      await Hive.openBox('cache'),
      cacheLimit: 2,
      clock: () => time,
    );
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'Personal library survives reopening and demo/live IDs do not collide',
    () async {
      final provider = LibraryProvider(storage);
      const live = Game(id: 1, title: 'Live');
      const demo = Game(id: 1, title: 'Demo', demo: true);
      await provider.save(
        LibraryEntry(
          game: live,
          status: LibraryStatus.completed,
          notes: 'Finished!',
          personalRating: 9,
          favorite: true,
        ),
      );
      await provider.save(
        LibraryEntry(game: demo, status: LibraryStatus.playing),
      );
      await storage.library.close();
      final box = await Hive.openBox<LibraryEntry>('library');
      expect(box.get(live.key)!.notes, 'Finished!');
      expect(box.get(live.key)!.personalRating, 9);
      expect(box.get(live.key)!.status, LibraryStatus.completed);
      expect(box.get(live.key)!.favorite, true);
      final reopened = LibraryProvider(
        AppStorage(box, storage.preferences, storage.cache),
      );
      await reopened.favorite(live);
      expect(reopened.entry(live)!.favorite, false);
      expect(reopened.entry(live)!.notes, 'Finished!');
      await reopened.remove(live);
      expect(reopened.entries(false), isEmpty);
      expect(reopened.entries(true), hasLength(1));
    },
  );
  test(
    'Cache expiry, oldest eviction and clearing preserve personal data',
    () async {
      await storage.library.put(
        'igdb:3',
        LibraryEntry(game: const Game(id: 3, title: 'Saved')),
      );
      await storage.remember('a', {});
      time = time.add(const Duration(hours: 24));
      expect(storage.expired(storage.cached('a')!), true);
      await storage.remember('b', {});
      time = time.add(const Duration(seconds: 1));
      await storage.remember('c', {});
      expect(storage.cached('a'), null);
      expect(storage.cache.length, 2);
      await storage.clearCache();
      expect(storage.library.get('igdb:3')!.game.title, 'Saved');
    },
  );
  test('Version-one optional fields have backward-compatible defaults', () {
    final entry = LibraryEntry.fromJson({
      'game': {'id': 1, 'title': 'Legacy'},
    });
    expect(entry.notes, '');
    expect(entry.favorite, false);
    expect(entry.personalRating, null);
  });
  test(
    'Discovery excludes playing and completed but keeps saved and source isolation',
    () async {
      final library = LibraryProvider(storage);
      const playing = Game(id: 501, title: 'Playing', source: 'rawg');
      const completed = Game(id: 502, title: 'Completed', source: 'rawg');
      const saved = Game(id: 503, title: 'Saved', source: 'rawg');
      await library.startPlaying(playing);
      await library.save(
        LibraryEntry(game: completed, status: LibraryStatus.completed),
      );
      await library.save(
        LibraryEntry(game: saved, status: LibraryStatus.wantToPlay),
      );
      expect(library.excludedFromDiscovery(playing), isTrue);
      expect(library.excludedFromDiscovery(completed), isTrue);
      expect(library.excludedFromDiscovery(saved), isFalse);
      expect(
        library.excludedFromDiscovery(
          const Game(id: 501, title: 'Other', source: 'igdb'),
        ),
        isFalse,
      );
      library.dispose();
    },
  );

  test(
    'Text search uses normalized relevance while explicit ordering remains available',
    () async {
      final fixture = FixtureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.rawg.io/api'))
        ..httpClientAdapter = fixture;
      final api = ApiService(client: dio, apiKey: () => 'fixture');
      await api.get('/games', {
        'q': '  Grand   Theft Auto  ',
        'sort': 'relevance',
      });
      expect(
        fixture.lastRequest!.queryParameters['search'],
        'Grand Theft Auto',
      );
      expect(
        fixture.lastRequest!.queryParameters.containsKey('ordering'),
        isFalse,
      );
      await api.get('/games', {'q': 'Portal', 'sort': 'rating'});
      expect(fixture.lastRequest!.queryParameters['ordering'], '-rating');
      final provider = SearchProvider(ControlledRepository(storage));
      provider.setQuery('Portal');
      expect(provider.sort, 'relevance');
      provider.sort = 'rating';
      provider.setQuery('Portal 2');
      expect(provider.sort, 'rating');
      provider.sort = 'relevance';
      provider.setQuery('   ');
      expect(provider.sort, 'popular');
      provider.dispose();
    },
  );

  testWidgets('Search debounces for 350ms and sends only the final query', (
    tester,
  ) async {
    final repo = ControlledRepository(storage);
    final p = SearchProvider(repo);
    p.setQuery('a');
    await tester.pump(const Duration(milliseconds: 200));
    p.setQuery('atlas');
    await tester.pump(const Duration(milliseconds: 349));
    expect(repo.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repo.calls, ['atlas:0:null']);
    repo.requests.single.complete(const CatalogResult([]));
    await tester.pump();
    p.dispose();
  });
  test(
    'Search rejects old responses, keeps filters and deduplicates pages',
    () async {
      final repo = ControlledRepository(storage);
      final p = SearchProvider(repo);
      final old = p.search();
      p.genre = '12';
      p.query = 'new';
      final fresh = p.search();
      expect(repo.tokens.first!.isCancelled, true);
      repo.requests[1].complete(
        const CatalogResult([Game(id: 2, title: 'New')], hasMore: true),
      );
      await fresh;
      repo.requests[0].complete(
        const CatalogResult([Game(id: 1, title: 'Old')]),
      );
      await old;
      expect(p.games.single.id, 2);
      expect(p.genre, '12');
      expect(p.query, 'new');
      final more = p.search(more: true);
      repo.requests[2].complete(
        const CatalogResult([
          Game(id: 2, title: 'New'),
          Game(id: 3, title: 'Next'),
        ]),
      );
      await more;
      expect(p.games.map((g) => g.id), [2, 3]);
      expect(p.hasMore, false);
      p.dispose();
    },
  );
  test('API errors, malformed responses and stale offline cache', () async {
    final adapter = FixtureAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.test'))
      ..httpClientAdapter = adapter;
    final api = ApiService(client: dio, apiKey: () => 'fixture-key');
    final repo = GameRepository(storage, api);
    final first = await repo.games(demo: false);
    expect(first.games.single.id, 42);
    expect(first.stale, false);
    time = time.add(const Duration(days: 2));
    adapter.fail = true;
    final offline = await repo.games(demo: false);
    expect(offline.stale, true);
    await expectLater(
      repo.games(demo: false, query: 'uncached'),
      throwsA(isA<ApiFailure>()),
    );
    adapter.fail = false;
    adapter.malformed = true;
    await expectLater(api.get('/games', {}), throwsA(isA<ApiFailure>()));
    dio.close();
  });
  test(
    'RAWG requests go directly to HTTPS and map paging, filters, ratings and source IDs',
    () async {
      final adapter = FixtureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://api.rawg.io/api'))
        ..httpClientAdapter = adapter;
      final api = ApiService(client: dio, apiKey: () => 'fixture-key');
      final data = await api.get('/games', {
        'feed': 'search',
        'q': 'Batman',
        'page': 2,
        'genre': '4',
        'platform': '21',
        'year': 2025,
        'sort': 'rating',
      });
      final request = adapter.lastRequest!;
      expect(request.uri.host, 'api.rawg.io');
      expect(request.uri.path, '/api/games');
      expect(request.queryParameters['page'], 3);
      expect(request.queryParameters['search'], 'Batman');
      expect(request.queryParameters['dates'], '2025-01-01,2025-12-31');
      expect(request.queryParameters['platforms'], '21');
      expect(request.queryParameters['ordering'], '-rating');
      final game = Game.fromJson(Map<String, dynamic>.from(data['games'][0]));
      expect(game.key, 'rawg:42');
      expect(game.rating, 90);
      expect(game.links, isEmpty);
      expect(game.trailers, isEmpty);
      final legacy = Game.fromJson({'id': 42, 'title': 'Old game'});
      expect(legacy.key, 'igdb:42');
      expect(legacy.key, isNot(game.key));
      dio.close();
    },
  );
  test(
    'Saving a validated RAWG key automatically disables demo without touching the library',
    () async {
      final adapter = FixtureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://fixture.test'))
        ..httpClientAdapter = adapter;
      final repo = GameRepository(storage, ApiService(client: dio));
      final settings = SettingsProvider(storage, repo);
      await storage.library.put(
        'igdb:9',
        LibraryEntry(
          game: const Game(id: 9, title: 'Preserved'),
          notes: 'Keep me',
        ),
      );
      expect(settings.demo, true);
      await settings.saveApiKey(' personal-fixture-key ');
      expect(settings.demo, false);
      expect(settings.hasApiKey, true);
      expect(settings.connectionRevision, 1);
      expect(
        adapter.lastRequest!.queryParameters['key'],
        'personal-fixture-key',
      );
      expect(storage.library.get('igdb:9')!.notes, 'Keep me');
      adapter.fail = true;
      await expectLater(settings.saveApiKey('bad'), throwsA(isA<ApiFailure>()));
      expect(storage.preferences.get('rawgApiKey'), 'personal-fixture-key');
      settings.dispose();
      dio.close();
    },
  );
  test('Missing RAWG key fails before sending a request', () async {
    final adapter = FixtureAdapter();
    final dio = Dio()..httpClientAdapter = adapter;
    await expectLater(
      ApiService(client: dio, apiKey: () => '').get('/games', {}),
      throwsA(isA<ApiFailure>()),
    );
    expect(adapter.lastRequest, null);
    dio.close();
  });
  test('Missing RAWG fields stay unknown and unsafe images are omitted', () {
    final game = ApiService.normalize({
      'id': 7,
      'name': 'Sparse',
      'rating': 0,
      'background_image': 'javascript:bad',
      'website': 'http://insecure.test',
    });
    expect(game.rating, null);
    expect(game.release, null);
    expect(game.cover, null);
    expect(game.summary, '');
    expect(game.links, isEmpty);
  });
  testWidgets('Responsive navigation and offline local library editing', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(GameAtlas(storage: storage));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Demo · fictional sample data'), findsOneWidget);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('My library'));
    await tester.pumpAndSettle();
    expect(find.text('Make room for your next favorite'), findsOneWidget);
    await tester.runAsync(
      () => tester
          .element(find.text('Make room for your next favorite'))
          .read<LibraryProvider>()
          .save(
            LibraryEntry(
              game: const Game(id: 1, title: 'Offline fixture', demo: true),
            ),
          ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Offline fixture'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review & notes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New entry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Offline note');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(
      CompanionRepository(storage).records('journal').single['notes'],
      'Offline note',
    );
    await tester.pumpWidget(const SizedBox());
    tester.view.physicalSize = const Size(1400, 1000);
    await tester.pumpWidget(GameAtlas(storage: storage));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Missing detail metadata and offline errors remain usable at large text scale',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<GameRepository>.value(value: FailingRepository(storage)),
            Provider(
              create: (_) => PricingRepository(storage, PricingService()),
            ),
            ChangeNotifierProvider(create: (_) => LibraryProvider(storage)),
            ChangeNotifierProvider(
              create: (_) => JournalProvider(CompanionRepository(storage)),
            ),
            ChangeNotifierProvider(
              create: (_) =>
                  DiscoveryPreferencesProvider(CompanionRepository(storage)),
            ),
            ChangeNotifierProvider(
              create: (_) => LineUpProvider(CompanionRepository(storage)),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const DetailsPage(
              initial: Game(id: 999, title: 'Unknown', source: 'rawg'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Showing saved game summary'), findsOneWidget);
      expect(find.text('Offline fixture'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('No description available.'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('No description available.'), findsOneWidget);
      expect(find.text('Watch & play'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Empty and error states provide a working retry action', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState('Unavailable', 'Try later', retry: () => retries++),
        ),
      ),
    );
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });
  testWidgets(
    'Home hides played games; My games and Profile wheel retain saved history',
    (tester) async {
      await tester.runAsync(() async {
        for (final game in demoGames) {
          await storage.library.put(
            game.key,
            LibraryEntry(
              game: game,
              status: game.id == 2
                  ? LibraryStatus.wantToPlay
                  : LibraryStatus.completed,
            ),
          );
        }
        final settings = SettingsProvider(
          storage,
          ControlledRepository(storage),
        );
        await settings.setDisplayName('Atlas Player');
        settings.dispose();
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(GameAtlas(storage: storage));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      expect(find.text('Local Game Wallet profile'), findsOneWidget);
      expect(find.text('11'), findsOneWidget);
      await tester.tap(find.text('Completed').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('11 games in this view'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(storage.preferences.get('displayName'), 'Atlas Player');
      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.text('Hi, Atlas Player'), findsOneWidget);
      expect(find.text(demoGames.first.title), findsNothing);
      await tester.tap(find.text('My games').last);
      await tester.pumpAndSettle();
      expect(find.text('Ready for your next adventure?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tracking-tab-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Search my games'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Neon Outriders');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Card, 'Neon Outriders'), findsOneWidget);
      expect(find.byTooltip('View style'), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      await tester.ensureVisible(find.text('Neon Outriders').last);
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Neon Outriders').last);
      await tester.pumpAndSettle();
      expect(find.text('Game actions'), findsOneWidget);
      expect(find.text('Add to LineUp'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('View style'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('View style'));
      await tester.pumpAndSettle();
      expect(find.text('Compact grid'), findsOneWidget);
      expect(find.text('Large grid'), findsOneWidget);
      expect(find.text('List'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.ensureVisible(
          find.byTooltip('Start playing Neon Outriders'),
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Start playing Neon Outriders'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final started = storage.library.get(
        demoGames.firstWhere((g) => g.id == 2).key,
      )!;
      expect(started.status, LibraryStatus.playing);
      expect(started.bookmarked, true);
      expect(find.text('Continue playing'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('tracking-tab-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tracking-tab-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), demoGames.first.title);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Card, demoGames.first.title), findsOneWidget);
      await tester.tap(find.text('Profile').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Spin wheel'));
      await tester.tap(find.text('Spin wheel'));

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Spin'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Spin'));
      await tester.pumpAndSettle();
      expect(find.text('Neon Outriders'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
