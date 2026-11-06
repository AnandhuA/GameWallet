import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:game_atlas/core/api_service.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/core/image_cache_service.dart';
import 'package:game_atlas/core/storage.dart';
import 'package:game_atlas/core/catalog_identity.dart';
import 'package:game_atlas/core/freetogame_service.dart';
import 'package:game_atlas/core/federated_game_repository.dart';
import 'package:game_atlas/core/companion_repository.dart';
import 'package:game_atlas/core/companion_models.dart';
import 'package:game_atlas/features/library/library_provider.dart';
import 'package:game_atlas/features/companion/companion_providers.dart';
import 'package:game_atlas/features/explore/search_provider.dart';
import 'package:game_atlas/features/details/details_page.dart';
import 'package:game_atlas/main.dart';
import 'package:game_atlas/shared/widgets.dart';

const primary = Game(
  id: 1,
  title: 'Shared game',
  source: 'rawg',
  release: null,
  platforms: ['PC'],
);
Map<String, dynamic> free({
  int id = 1,
  String title = 'Shared game',
  String platform = 'PC (Windows)',
  String genre = 'Shooter',
}) => {
  'id': id,
  'title': title,
  'short_description': 'Supplementary description',
  'thumbnail': 'https://fixture.test/cover.png',
  'release_date': '2025-01-02',
  'developer': 'Fixture Studio',
  'publisher': 'Fixture Publisher',
  'genre': genre,
  'platform': platform,
  'game_url': 'https://fixture.test/game/$id',
  'screenshots': [
    {'image': 'https://fixture.test/shot.png'},
  ],
};
Game raw({int id = 1, String title = 'Shared game', int year = 2025}) => Game(
  id: id,
  title: title,
  source: 'rawg',
  release: DateTime(year, 1, 2),
  developers: ['Fixture Studio'],
  platforms: ['PC'],
);

class RawFixture extends ApiService {
  bool fail = false;
  List<Game> records = [raw()];
  Map<int, List<Game>> pages = {};
  int calls = 0;
  @override
  Future<dynamic> get(
    String path,
    Map<String, dynamic> query, {
    CancelToken? cancel,
  }) async {
    calls++;
    if (fail) throw const ApiFailure('RAWG offline fixture');
    if (path == '/filters') {
      return {
        'genres': [
          {'id': 2, 'name': 'Shooter'},
        ],
        'platforms': [
          {'id': 4, 'name': 'PC'},
        ],
      };
    }
    if (path == '/games') {
      final page = query['page'] as int? ?? 0;
      return {
        'games': (pages[page] ?? records).map((g) => g.toJson()).toList(),
        'hasMore': pages.containsKey(page + 1),
      };
    }
    return {'game': records.first.toJson()};
  }
}

class FreeFixture extends FreeToGameService {
  List<dynamic> records = [free()];
  bool fail = false, malformed = false;
  int calls = 0, active = 0, maxActive = 0;
  Completer<void>? gate;
  @override
  Future<dynamic> get(
    String path,
    Map<String, dynamic> query,
    CancelToken cancel,
  ) async {
    calls++;
    active++;
    if (active > maxActive) maxActive = active;
    try {
      if (gate != null) await gate!.future;
      if (cancel.isCancelled) throw cancel.cancelError!;
      if (fail) throw const SocketException('FreeToGame offline fixture');
      if (malformed) return {'bad': 'data'};
      return path == '/games'
          ? records
          : records.firstWhere((j) => j['id'] == query['id']);
    } finally {
      active--;
    }
  }
}

class _LiveNetwork extends HttpOverrides {}

void main() {
  late Directory directory;
  late AppStorage storage;
  late RawFixture rawApi;
  late FreeFixture freeApi;
  late FreeToGameRepository secondary;
  late CatalogIdentity identities;
  late FederatedGameRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wallet_sources_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LibraryEntryAdapter());
    }
    storage = AppStorage(
      await Hive.openBox<LibraryEntry>('library'),
      await Hive.openBox('prefs'),
      await Hive.openBox('cache'),
      personal: await Hive.openBox('personal'),
      images: await Hive.openBox('images'),
    );
    rawApi = RawFixture();
    freeApi = FreeFixture();
    secondary = FreeToGameRepository(storage, freeApi);
    identities = CatalogIdentity(storage);
    repository = FederatedGameRepository(
      storage,
      rawApi,
      secondary,
      identities,
    );
  });
  tearDown(() async {
    secondary.dispose();
    identities.dispose();
    rawApi.dio.close(force: true);
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'normalization, optional values and legacy JSON retain stable source identities',
    () {
      final game = normalizeFreeToGame(free());
      expect(game.key, 'freetogame:1');
      expect(game.rating, isNull);
      expect(game.screenshots, hasLength(1));
      expect(game.platforms, ['PC']);
      expect(game.developers, ['Fixture Studio']);
      expect(
        Game.fromJson({'id': 4, 'title': 'Legacy'}).fallbackImages,
        isEmpty,
      );
      expect(Game.fromJson(game.toJson()).provenance['cover'], 'freetogame');
      expect(() => normalizeFreeToGame({'id': 'bad'}), throwsFormatException);
    },
  );
  test(
    'matching separates editions, companies, release years and source-local ID collisions',
    () async {
      expect(confirmedCatalogMatch(raw(), normalizeFreeToGame(free())), isTrue);
      expect(
        confirmedCatalogMatch(
          raw(title: 'Shared game Deluxe'),
          normalizeFreeToGame(free()),
        ),
        isFalse,
      );
      expect(
        confirmedCatalogMatch(raw(year: 2020), normalizeFreeToGame(free())),
        isFalse,
      );
      expect(
        confirmedCatalogMatch(primary, normalizeFreeToGame(free())),
        isFalse,
      );
      rawApi.records = [raw(title: 'Different game')];
      final result = await repository.games(demo: false);
      expect(result.games.map((g) => g.key).toSet(), {
        'rawg:1',
        'freetogame:1',
      });
    },
  );
  test(
    'confirmed matches produce one card, preserve primary fields and add same-game fallbacks',
    () async {
      final result = await repository.games(demo: false);
      expect(result.games, hasLength(1));
      final game = result.games.single;
      expect(game.key, 'rawg:1');
      expect(game.summary, 'Supplementary description');
      expect(game.fallbackImages, contains('https://fixture.test/cover.png'));
      expect(game.provenance['summary'], 'freetogame');
      expect(identities.keys(game.key), {'rawg:1', 'freetogame:1'});
    },
  );
  test(
    'uncertain same-title secondary cards stay hidden until explicit confirmation',
    () async {
      rawApi.records = [primary];
      final result = await repository.games(demo: false);
      expect(result.games.map((g) => g.key), ['rawg:1']);
      expect(identities.keys('rawg:1'), {'rawg:1'});
      final matches = await repository.otherMatches(primary);
      expect(matches, hasLength(1));
      await repository.confirmMatch(primary, matches.single);
      expect(
        (await repository.detailGame(primary)).$1.summary,
        'Supplementary description',
      );
    },
  );
  test(
    'alias links survive reopening and clearing without moving personal records',
    () async {
      final game = normalizeFreeToGame(free());
      await storage.library.put(
        game.key,
        LibraryEntry(game: game, status: LibraryStatus.playing),
      );
      await storage.personal!.put('journal:keep', {'notes': 'Keep this'});
      await identities.link(raw(), game);
      await storage.clearCache();
      await storage.personal!.close();
      final again = AppStorage(
        storage.library,
        storage.preferences,
        storage.cache,
        personal: await Hive.openBox('personal'),
      );
      final links = CatalogIdentity(again);
      expect(links.keys('rawg:1'), contains('freetogame:1'));
      expect(storage.library.keys.toList(), ['freetogame:1']);
      expect(again.personal!.get('journal:keep')['notes'], 'Keep this');
      links.dispose();
    },
  );
  test(
    'playing, completed and hidden exclusions follow confirmed aliases',
    () async {
      final game = normalizeFreeToGame(free());
      await identities.link(raw(), game);
      final library = LibraryProvider(storage, identities: identities);
      final hidden = DiscoveryPreferencesProvider(
        CompanionRepository(storage),
        identities: identities,
      );
      await library.startPlaying(game);
      expect(library.excludedFromDiscovery(raw()), isTrue);
      await library.completePlaythrough(game, library.completionDraft(game));
      expect(library.hasPlayed(raw()), isTrue);
      await hidden.setHidden(game, true);
      expect(hidden.hidden(raw()), isTrue);
      library.dispose();
      hidden.dispose();
    },
  );
  test(
    'editing an alias preserves saved IDs and makes reviews visible through both sources',
    () async {
      final extra = normalizeFreeToGame(free());
      await storage.library.put(
        extra.key,
        LibraryEntry(game: extra, status: LibraryStatus.wantToPlay),
      );
      await identities.link(raw(), extra);
      final library = LibraryProvider(storage, identities: identities);
      await library.favorite(raw());
      expect(storage.library.keys.toList(), ['freetogame:1']);
      expect(library.entry(raw())!.favorite, isTrue);
      expect(library.entry(raw())!.game.summary, 'Supplementary description');
      await library.startPlaying(raw());
      expect(storage.library.keys.toList(), ['freetogame:1']);
      final journal = JournalProvider(
        CompanionRepository(storage),
        identities: identities,
      );
      await journal.save(PlaythroughEntry(id: 'kept', game: extra, rating: 4));
      expect(journal.entries(false, gameKey: raw().key), hasLength(1));
      library.dispose();
      journal.dispose();
    },
  );

  test(
    'concurrent confirmations preserve a transitive identity group',
    () async {
      final a = normalizeFreeToGame(free(id: 2)),
          b = normalizeFreeToGame(free(id: 3));
      await Future.wait([identities.link(raw(), a), identities.link(raw(), b)]);
      expect(identities.keys(a.key), {
        'rawg:1',
        'freetogame:2',
        'freetogame:3',
      });
      expect(identities.canonical(a.key), identities.canonical(b.key));
    },
  );

  test(
    'primary failure preserves supplementary results and restrictive platform filters',
    () async {
      rawApi.fail = true;
      final result = await repository.games(demo: false, platform: '4');
      expect(result.games.single.source, 'freetogame');
      expect(result.notice, contains('RAWG unavailable'));
      expect(
        (await repository.games(demo: false, platform: '21')).games,
        isEmpty,
      );
      expect(
        (await repository.games(demo: false, genre: 'unknown')).games,
        isEmpty,
      );
      expect(
        (await repository.games(demo: false, platform: '4,18')).games,
        hasLength(1),
      );
      expect((await repository.games(demo: false, year: 1990)).games, isEmpty);
    },
  );
  test(
    'secondary failure leaves RAWG usable; both failures surface an error',
    () async {
      freeApi.fail = true;
      final result = await repository.games(demo: false);
      expect(result.games.single.source, 'rawg');
      expect(result.notice, contains('FreeToGame unavailable'));
      await storage.clearCache();
      rawApi.fail = true;
      await expectLater(
        repository.games(demo: false),
        throwsA(isA<ApiFailure>()),
      );
    },
  );
  test(
    'ratings and named popularity feeds do not invent comparable secondary scores',
    () async {
      rawApi.records = [raw(title: 'Unrelated')];
      expect(
        (await repository.games(
          demo: false,
          sort: 'rating',
        )).games.every((g) => g.source == 'rawg'),
        isTrue,
      );
      expect(
        (await repository.games(
          demo: false,
          feed: 'popular',
        )).games.every((g) => g.source == 'rawg'),
        isTrue,
      );
      expect(
        (await repository.games(
          demo: false,
          feed: 'freetoplay',
        )).games.single.rating,
        isNull,
      );
    },
  );
  test(
    'cross-page matching replaces a duplicate without losing earlier results',
    () async {
      rawApi.pages = {
        0: [raw(id: 10, title: 'Other game')],
        1: [raw(id: 2)],
      };
      final search = SearchProvider(repository)..demo = false;
      await search.search();
      expect(search.games, hasLength(2));
      await search.search(more: true);
      expect(search.games.where((g) => g.title == 'Shared game'), hasLength(1));
      expect(
        search.games.map(repository.canonicalKey).toSet().length,
        search.games.length,
      );
      search.dispose();
    },
  );
  test(
    'FTG details, personal actions, journal and plans retain their own IDs',
    () async {
      final game = normalizeFreeToGame(free());
      final result = await repository.detailGame(game);
      expect(result.$1.key, game.key);
      final library = LibraryProvider(storage);
      await library.startPlaying(result.$1);
      final companion = CompanionRepository(storage);
      final journal = JournalProvider(companion),
          calendar = CalendarProvider(companion);
      await journal.save(
        PlaythroughEntry(id: 'run', game: result.$1, rating: 4.5),
      );
      await calendar.save(
        PlaySessionPlan(
          id: 'plan',
          game: result.$1,
          scheduled: DateTime(2026, 11, 5),
        ),
      );
      expect(journal.entries(false).single.game.key, game.key);
      expect(calendar.entries(false).single.game.key, game.key);
      await library.completePlaythrough(
        result.$1,
        library.completionDraft(result.$1),
      );
      expect(library.hasPlayed(result.$1), isTrue);
      library.dispose();
      journal.dispose();
      calendar.dispose();
    },
  );
  test(
    'forced refresh, malformed data and stale independent cache fallback',
    () async {
      await secondary.read('/games', null);
      await secondary.read('/games', null);
      expect(freeApi.calls, 1);
      await secondary.read('/games', null, refresh: true);
      expect(freeApi.calls, 2);
      freeApi.malformed = true;
      expect((await secondary.read('/games', null, refresh: true)).$2, isTrue);
      await storage.clearCache();
      await expectLater(secondary.read('/games', null), throwsFormatException);
    },
  );
  test(
    'shared requests survive one reader cancellation and clearing prevents cache resurrection',
    () async {
      freeApi.gate = Completer<void>();
      final cancel = CancelToken();
      final first = secondary.read('/games', cancel);
      final firstFailure = expectLater(first, throwsA(isA<DioException>()));
      final second = secondary.read('/games', null);
      cancel.cancel('Old search');
      await firstFailure;
      await storage.clearCache();
      freeApi.gate!.complete();
      expect((await second).$1, hasLength(1));
      expect(freeApi.calls, 1);
      expect(storage.cache.isEmpty, isTrue);
    },
  );
  test(
    'detail concurrency is bounded and cached data survives reopening',
    () async {
      freeApi.records = [free(id: 1), free(id: 2), free(id: 3)];
      freeApi.gate = Completer<void>();
      final requests = [
        for (final id in [1, 2, 3]) secondary.read('/game', null, id: id),
      ];
      expect(freeApi.calls, 2);
      freeApi.gate!.complete();
      await Future.wait(requests);
      expect(freeApi.maxActive, 2);
      await storage.cache.close();
      final again = AppStorage(
        storage.library,
        storage.preferences,
        await Hive.openBox('cache'),
      );
      final cached = FreeToGameRepository(again, freeApi);
      expect((await cached.read('/game', null, id: 1)).$1.single.id, 1);
      expect(freeApi.calls, 3);
    },
  );

  test(
    'both offline catalogs use their own stale caches without repeated cards',
    () async {
      await repository.games(demo: false);
      rawApi.fail = true;
      freeApi.fail = true;
      final result = await repository.games(demo: false, forceRefresh: true);
      expect(result.stale, isTrue);
      expect(result.games, hasLength(1));
    },
  );

  test(
    'confirmed RAWG details load full supplementary metadata without changing identity',
    () async {
      final initial = raw();
      freeApi.records = [
        {...free(), 'description': 'Full supplementary description'},
      ];
      final result = await repository.detailGame(initial);
      expect(result.$1.summary, 'Full supplementary description');
      expect(result.$1.key, 'rawg:1');
      expect(result.$1.screenshots, contains('https://fixture.test/shot.png'));
    },
  );

  test(
    'supplementary pagination freezes its snapshot until a fresh search',
    () async {
      rawApi.records = [];
      freeApi.records = [
        for (var i = 0; i < 25; i++) free(id: i + 1, title: 'Free game $i'),
      ];
      final first = await repository.games(demo: false);
      expect(first.games, hasLength(20));
      freeApi.records = [free(id: 999, title: 'New arrival')];
      final next = await repository.games(demo: false, page: 1);
      expect(next.games, hasLength(5));
      expect(next.games.any((g) => g.id == 999), isFalse);
      final refreshed = await repository.games(demo: false, forceRefresh: true);
      expect(refreshed.games.single.id, 999);
    },
  );

  test('precise federated matching retains RAWG precise request flags', () async {
    // A distinct precise-cache entry verifies that broad metadata is not reused.
    await repository.games(
      demo: false,
      query: 'Shared game',
      precise: true,
      sort: 'relevance',
    );
    expect(
      storage.cache.keys.whereType<String>().any(
        (k) => k.startsWith('rawg:') && k.contains('"precise":true'),
      ),
      isTrue,
    );
  });

  test(
    'live FreeToGame smoke check',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final service = FreeToGameService();
      try {
        final live = FreeToGameRepository(storage, service);
        final records = (await live.read('/games', null, refresh: true)).$1;
        expect(records, isNotEmpty);
        expect(
          records.every((g) => g.source == 'freetogame' && g.rating == null),
          isTrue,
        );
        expect(
          (await live.read(
            '/game',
            null,
            id: records.first.id,
            refresh: true,
          )).$1.single.id,
          records.first.id,
        );
        if (records.first.cover != null) {
          final images = ImageCacheService(null);
          try {
            expect(await images.load(records.first.cover!), isNotEmpty);
          } finally {
            images.dispose();
          }
        }
      } finally {
        service.dispose();
      }
    }, _LiveNetwork()),
    skip: !const bool.fromEnvironment('FREETOGAME_LIVE'),
  );

  for (final width in [390.0, 1280.0]) {
    testWidgets('cached FTG-only discovery and details at $width / 200%', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        await storage.preferences.putAll({
          'demo': false,
          'onboardingDismissed': true,
        });
        await storage.remember('freetogame:v1:/games:all', [free()]);
        await storage.remember('freetogame:v1:/game:1', free());
      });
      await tester.pumpWidget(GameAtlas(storage: storage));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('My games').first);
      final home = context.read<FreeToGameRepository>();
      expect(home, isNotNull);
      openGame(context, normalizeFreeToGame(free()));
      await tester.pumpAndSettle();
      expect(find.byType(DetailsPage), findsOneWidget);
      expect(find.text('Shared game'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Catalog sources'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('FreeToGame'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
