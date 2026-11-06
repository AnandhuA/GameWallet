import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:game_atlas/features/settings/settings_provider.dart';
import 'package:game_atlas/core/image_cache_service.dart';
import 'image_fallback_test.dart' show FakeImages, settleImages;
import 'package:hive_ce/hive.dart';
import 'package:game_atlas/core/api_service.dart';
import 'package:game_atlas/core/game_repository.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/core/storage.dart';
import 'package:game_atlas/features/deals/deal_record.dart';
import 'package:game_atlas/features/deals/deal_cover.dart';
import 'package:game_atlas/features/deals/deal_details_page.dart';
import 'package:game_atlas/features/deals/deals_catalog_provider.dart';
import 'package:game_atlas/features/deals/deals_repository.dart';
import 'package:game_atlas/features/deals/deals_provider.dart';
import 'package:game_atlas/features/deals/deals_service.dart';
import 'package:game_atlas/main.dart';

const game = Game(
  id: 42,
  title: 'Fixture Game',
  source: 'rawg',
  platforms: ['PC'],
  summary: 'A fixture description.',
);
DealRecord record({
  String title = 'Fixture Game',
  String platform = 'pc',
  String? steam,
}) => DealRecord(
  title: title,
  platform: platform,
  storeUrl: 'https://store.epicgames.com/en-US/p/fixture',
  recordedDate: DateTime(2026, 10, 29),
  steamUrl: steam,
);

class EmptyFeed extends DealsService {
  @override
  Future<dynamic> fetch(CancelToken cancel) async => <dynamic>[];
}

class ConfiguredSettings extends SettingsProvider {
  ConfiguredSettings(GameRepository repository)
    : super(repository.storage, repository);
  @override
  bool get hasApiKey => true;
}

class CatalogFixture extends GameRepository {
  CatalogFixture(AppStorage storage) : super(storage, ApiService());
  int calls = 0, active = 0, maxActive = 0;
  bool? lastPrecise;
  Future<CatalogResult> Function(String)? response;
  Future<(Game, bool)> Function(int, CancelToken?)? detailResponse;
  @override
  Future<CatalogResult> games({
    required bool demo,
    String feed = 'search',
    String query = '',
    String? genre,
    String? platform,
    int? year,
    String sort = 'popular',
    bool precise = false,
    int page = 0,
    CancelToken? cancel,
    bool forceRefresh = false,
  }) async {
    calls++;
    lastPrecise = precise;
    active++;
    if (active > maxActive) maxActive = active;
    try {
      return await (response?.call(query) ??
          Future.value(const CatalogResult([game])));
    } finally {
      active--;
    }
  }

  @override
  Future<(Game, bool)> detail(
    int id,
    bool demo, {
    CancelToken? cancel,
    bool forceRefresh = false,
  }) => detailResponse?.call(id, cancel) ?? Future.value((game, false));
}

void main() {
  late Directory directory;
  late AppStorage storage;
  late CatalogFixture repository;
  late DealsCatalogProvider catalog;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wallet_deal_details_');
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
    repository = CatalogFixture(storage);
    catalog = DealsCatalogProvider(repository);
  });
  tearDown(() async {
    catalog.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'Steam artwork requires a safe feed-supplied app link and survives serialization',
    () {
      final r = record(
        steam: 'https://store.steampowered.com/app/264710/Subnautica/',
      );
      expect(r.steamAppId, '264710');
      expect(r.coverSources, hasLength(2));
      expect(DealRecord.fromEpic(r.toJson())!.steamAppId, '264710');
      expect(
        record(
          steam: 'https://store.steampowered.com.evil/app/42',
        ).coverSources,
        isEmpty,
      );
      expect(record(steam: 'javascript:alert(1)').coverSources, isEmpty);
      expect(
        record(steam: 'https://store.steampowered.com:444/app/42').coverSources,
        isEmpty,
      );
    },
  );
  test(
    'matching refuses editions, ambiguous titles, wrong platforms and incomplete searches',
    () {
      expect(
        exactDealMatch(record(), const CatalogResult([game]))!.key,
        'rawg:42',
      );
      expect(
        exactDealMatch(
          record(title: 'Fixture Game Deluxe'),
          const CatalogResult([game]),
        ),
        isNull,
      );
      expect(
        exactDealMatch(
          record(platform: 'android'),
          const CatalogResult([game]),
        ),
        isNull,
      );
      expect(
        exactDealMatch(record(), const CatalogResult([game, game])),
        isNull,
      );
      expect(
        exactDealMatch(record(), const CatalogResult([game], hasMore: true)),
        isNull,
      );
    },
  );
  test(
    'artwork searches deduplicate, limit concurrency and respect cache clearing',
    () async {
      final gate = Completer<void>();
      repository.response = (_) async {
        await gate.future;
        return const CatalogResult([game]);
      };
      final first = catalog.lookup(record());
      final same = catalog.lookup(record());
      final second = catalog.lookup(record(title: 'Second'));
      final third = catalog.lookup(record(title: 'Third'));
      expect(repository.calls, 2);
      await storage.clearCache();
      gate.complete();
      await Future.wait([first, same, second, third]);
      expect(repository.maxActive, 2);
      expect(catalog.coverGame(record()), isNull);
      await catalog.lookup(record());
      expect(catalog.coverGame(record())!.id, 42);
    },
  );
  test(
    'details auto-match, offline metadata and explicit selection preserve identities',
    () async {
      final p = DealDetailsProvider(catalog, record());
      repository.detailResponse = (_, _) async => (game, true);
      await p.load();
      expect(p.game!.key, 'rawg:42');
      expect(p.stale, isTrue);
      p.dispose();
      repository.response = (_) async => const CatalogResult([game, game]);
      final ambiguous = DealDetailsProvider(catalog, record());
      await ambiguous.load(refresh: true);
      expect(ambiguous.game, isNull);
      expect(ambiguous.candidates, hasLength(2));
      await ambiguous.select(ambiguous.candidates.first);
      expect(ambiguous.game!.key, 'rawg:42');
      ambiguous.dispose();
    },
  );
  test(
    'details failures and disposal leave the source record usable',
    () async {
      repository.response = (_) async => throw const SocketException('Offline');
      final p = DealDetailsProvider(catalog, record());
      await p.load();
      expect(p.error, isNotNull);
      expect(p.record.title, 'Fixture Game');
      p.dispose();
      final gate = Completer<(Game, bool)>();
      repository.detailResponse = (_, _) => gate.future;
      final disposed = DealDetailsProvider(catalog, record());
      final request = disposed.select(game);
      disposed.dispose();
      gate.complete((game, false));
      await request;
    },
  );
  test(
    'late detail responses cannot overwrite a newer manual selection',
    () async {
      final old = Completer<(Game, bool)>();
      const other = Game(id: 43, title: 'Confirmed edition', source: 'rawg');
      repository.detailResponse = (id, _) =>
          id == 42 ? old.future : Future.value((other, false));
      final p = DealDetailsProvider(catalog, record());
      final first = p.select(game);
      await p.select(other);
      old.complete((game, false));
      await first;
      expect(p.game!.key, 'rawg:43');
      p.dispose();
    },
  );

  for (final steamBroken in [false, true]) {
    testWidgets(
      'cover renders RAWG artwork after ${steamBroken ? 'Steam failures' : 'precise lookup'}',
      (tester) async {
        const pictured = Game(
          id: 42,
          title: 'Fixture Game',
          source: 'rawg',
          platforms: ['PC'],
          cover: 'https://fixture.test/cover.png',
        );
        repository.response = (_) async => const CatalogResult([pictured]);
        final images = FakeImages({
          'https://fixture.test/cover.png': File(
            'assets/art/1.png',
          ).readAsBytesSync(),
        });
        final settings = ConfiguredSettings(repository);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<DealsCatalogProvider>.value(
                value: catalog,
              ),
              ChangeNotifierProvider<SettingsProvider>.value(value: settings),
              ChangeNotifierProvider<ImageCacheService>.value(value: images),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 64,
                  height: 86,
                  child: DealCover(
                    record(
                      steam: steamBroken
                          ? 'https://store.steampowered.com/app/42/'
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await settleImages(tester);
        expect(repository.lastPrecise, isTrue);
        expect(images.requests.last, 'https://fixture.test/cover.png');
        expect(find.byType(Image), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        settings.dispose();
        images.dispose();
      },
    );
  }

  testWidgets(
    'refresh retries unavailable artwork instead of retaining an empty match',
    (tester) async {
      final feed = EmptyFeed();
      final deals = DealsProvider(DealsRepository(storage, feed));
      final images = FakeImages({
        'https://fixture.test/cover.png': File(
          'assets/art/1.png',
        ).readAsBytesSync(),
      });
      final settings = ConfiguredSettings(repository);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<DealsCatalogProvider>.value(value: catalog),
            ChangeNotifierProvider<SettingsProvider>.value(value: settings),
            ChangeNotifierProvider<ImageCacheService>.value(value: images),
            ChangeNotifierProvider<DealsProvider>.value(value: deals),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 64, height: 86, child: DealCover(record())),
            ),
          ),
        ),
      );
      await settleImages(tester);
      expect(find.byType(Image), findsNothing);
      repository.response = (_) async => const CatalogResult([
        Game(
          id: 42,
          title: 'Fixture Game',
          source: 'rawg',
          platforms: ['PC'],
          cover: 'https://fixture.test/cover.png',
        ),
      ]);
      await tester.runAsync(() => deals.load(refresh: true));
      await settleImages(tester);
      expect(find.byType(Image), findsOneWidget);
      expect(repository.calls, 2);
      await tester.pumpWidget(const SizedBox());
      deals.dispose();
      feed.dispose();
      settings.dispose();
      images.dispose();
    },
  );

  for (final width in [390.0, 1280.0]) {
    testWidgets('Deals tap opens details without a key at $width / 200%', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await storage.preferences.putAll({
          'demo': true,
          'onboardingDismissed': true,
        });
        await storage.remember(DealsRepository.cacheKey, [record().toJson()]);
      });
      await tester.pumpWidget(GameAtlas(storage: storage));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deals').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Fixture Game'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(DealCover), findsOneWidget);
      await tester.tap(find.text('Fixture Game'));
      await tester.pumpAndSettle();
      expect(find.byType(DealDetailsPage), findsOneWidget);
      expect(find.textContaining('historical giveaway'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Check on Epic'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Check on Epic'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
