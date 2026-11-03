import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/core/storage.dart';
import 'package:game_atlas/features/pricing/price_models.dart';
import 'package:game_atlas/features/pricing/pricing_service.dart';
import 'package:game_atlas/features/pricing/pricing_repository.dart';
import 'package:game_atlas/features/pricing/pricing_provider.dart';
import 'package:game_atlas/features/pricing/store_prices_section.dart';

const game = Game(id: 4, title: 'Portal 2', source: 'rawg');
const match = PriceMatch('36', 'Portal 2');

// Used only by the explicitly enabled live check. Widget fixtures retain
// Flutter's network blocking; this zone restores dart:io's real HttpClient.
class _LiveNetwork extends HttpOverrides {}

class PriceAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  List<dynamic> matches = [match.toJson()];
  dynamic listing = {
    'info': {'title': 'Portal 2'},
    'deals': <dynamic>[
      {
        'storeID': '1',
        'dealID': 'Steam%2Bdeal%3D',
        'price': '9.99',
        'retailPrice': '19.99',
      },
      {
        'storeID': '25',
        'dealID': 'Epic',
        'price': '5.00',
        'retailPrice': '19.99',
      },
      {'storeID': '99', 'dealID': 'unknown', 'price': '0.01'},
    ],
  };
  dynamic stores = [
    {'storeID': '1', 'storeName': 'Steam', 'isActive': 1},
    {'storeID': '25', 'storeName': 'Epic Games Store', 'isActive': 1},
  ];
  int status = 200;
  String retryAfter = '120';
  bool fail = false, malformed = false, cancelled = false;
  bool timeout = false;
  bool fxFail = false;
  dynamic rate = {
    'base': 'USD',
    'quote': 'INR',
    'date': '2026-11-03',
    'rate': 85.0,
  };
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (timeout) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    if (gate != null) {
      await Future.any([
        gate!.future,
        if (cancelFuture != null)
          cancelFuture.then((_) {
            cancelled = true;
            throw StateError('Request cancelled');
          }),
      ]);
    }
    final fx = options.path.contains('frankfurter.dev');
    final data = fx
        ? rate
        : options.path == '/stores'
        ? stores
        : options.queryParameters.containsKey('id')
        ? listing
        : matches;
    return ResponseBody.fromString(
      malformed ? 'not json' : jsonEncode(data),
      fail || (fx && fxFail) ? 503 : status,
      headers: {
        'content-type': ['application/json'],
        'retry-after': [retryAfter],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('PRICING_PREVIEWS')) {
      final fonts = FontLoader('PreviewSans')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                const String.fromEnvironment('PREVIEW_FONT'),
              ).readAsBytesSync(),
            ),
          ),
        );
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              File(
                const String.fromEnvironment('PREVIEW_ICONS'),
              ).readAsBytesSync(),
            ),
          ),
        );
      await fonts.load();
      await icons.load();
    }
  });
  late Directory directory;
  late AppStorage storage;
  late PriceAdapter adapter;
  late PricingService service;
  late PricingRepository repository;
  late DateTime now;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wallet_prices_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LibraryEntryAdapter());
    }
    now = DateTime.utc(2026, 11, 3, 12);
    storage = AppStorage(
      await Hive.openBox<LibraryEntry>('library'),
      await Hive.openBox('preferences'),
      await Hive.openBox('cache'),
      clock: () => now,
    );
    adapter = PriceAdapter();
    service = PricingService(
      dio: Dio(BaseOptions(baseUrl: 'https://www.cheapshark.com/api/1.0'))
        ..httpClientAdapter = adapter,
      clock: () => now,
    );
    repository = PricingRepository(storage, service);
  });
  tearDown(() async {
    service.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('rupee conversion rounds paise and uses Indian digit grouping', () {
    const rate = RupeeRate(85, '2026-11-03');
    expect(rate.money(500), '≈ ₹425.00');
    expect(rate.money(999), '≈ ₹849.15');
    expect(rate.money(0), '≈ ₹0.00');
    expect(rate.money(150000), '≈ ₹1,27,500.00');
    expect(const RupeeRate(85.555, '2026-11-03').money(1), '≈ ₹0.86');
    for (final bad in [0, -1, double.infinity, double.nan]) {
      expect(
        () => RupeeRate.fromJson({
          'base': 'USD',
          'quote': 'INR',
          'date': '2026-11-03',
          'rate': bad,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => RupeeRate.fromJson({
        'base': 'EUR',
        'quote': 'INR',
        'date': '2026-11-03',
        'rate': 85,
      }),
      throwsFormatException,
    );
  });

  test(
    'reference rate is cached daily, can be refreshed, and survives offline',
    () async {
      expect((await repository.rupeeRate(CancelToken()))!.rate, 85);
      now = now.add(const Duration(hours: 2));
      adapter.rate['rate'] = 86;
      expect((await repository.rupeeRate(CancelToken()))!.rate, 85);
      expect(adapter.requests.length, 1);
      expect(
        (await repository.rupeeRate(CancelToken(), refresh: true))!.rate,
        86,
      );
      now = now.add(const Duration(days: 1));
      adapter.fxFail = true;
      final stale = await repository.rupeeRate(CancelToken());
      expect(stale!.stale, true);
      expect(stale.rate, 86);
      await storage.clearCache();
      expect(await repository.rupeeRate(CancelToken()), isNull);
    },
  );

  test(
    'unavailable or malformed conversion does not hide USD offers',
    () async {
      adapter.fxFail = true;
      final result = await repository.listing(match, CancelToken());
      expect(result.offers, hasLength(2));
      expect(result.rupeeRate, isNull);
      adapter.fxFail = false;
      adapter.rate['rate'] = -1;
      expect(await repository.rupeeRate(CancelToken(), refresh: true), isNull);
    },
  );

  test('auto matching retains edition, DLC and bundle distinctions', () {
    expect(exactPriceMatch('Portal: 2™', [match]), match);
    expect(
      exactPriceMatch('Portal 2', [
        const PriceMatch('7', 'Portal 2 Deluxe Edition'),
      ]),
      isNull,
    );
    expect(
      exactPriceMatch('Portal 2', [const PriceMatch('7', 'Portal 2 DLC')]),
      isNull,
    );
    expect(
      exactPriceMatch('Portal 2', [const PriceMatch('7', 'Portal 2 Bundle')]),
      isNull,
    );
    expect(
      exactPriceMatch('Portal 2', [match, const PriceMatch('7', 'Portal 2')]),
      isNull,
    );
  });

  test(
    'prices use exact cents and safe provider redirect, encoding ID once',
    () {
      const offer = StoreOffer(
        storeId: '1',
        storeName: 'Steam',
        dealId: 'abc%2Bxyz%2F%3D',
        cents: 999,
        retailCents: 1999,
      );
      expect(offer.url.host, 'www.cheapshark.com');
      expect(offer.url.path, '/redirect');
      expect(offer.url.queryParameters, {'dealID': 'abc+xyz/='});
      expect(offer.discount, 50);
      expect(StoreOffer.parseCents('0'), 0);
      expect(StoreOffer.parseCents('9.9'), 990);
      expect(StoreOffer.parseCents('-1'), isNull);
      expect(StoreOffer.parseCents('NaN'), isNull);
      expect(StoreOffer.parseCents('1.001'), isNull);
      expect(StoreOffer.money(0), 'US\$0.00');
    },
  );

  test(
    'dynamic active stores, sorting, deduplication and absent retail prices',
    () async {
      (adapter.listing['deals'] as List).addAll([
        {'storeID': '1', 'dealID': 'Steam%2Bdeal%3D', 'price': '9.99'},
        {'storeID': '25', 'dealID': 'second', 'price': '12.99'},
      ]);
      final result = await repository.listing(match, CancelToken());
      expect(result.offers.map((o) => o.storeName), [
        'Epic Games Store',
        'Steam',
        'Epic Games Store',
      ]);
      expect(result.offers.last.retailCents, isNull);
      expect(result.offers.last.discount, isNull);
      expect(result.offers.first.discount, 75);
      adapter.stores[1]['isActive'] = 0;
      final refreshed = await repository.listing(
        match,
        CancelToken(),
        refresh: true,
      );
      expect(refreshed.offers.map((o) => o.storeName), ['Steam']);
    },
  );

  test(
    'title mismatch and malformed offers never cross-match editions',
    () async {
      adapter.listing['info']['title'] = 'Portal 2 Deluxe Edition';
      await expectLater(
        repository.listing(match, CancelToken()),
        throwsA(isA<PricingFailure>()),
      );
      adapter.listing['info']['title'] = 'Portal 2';
      adapter.listing['deals'][0]['price'] = 'not a price';
      await expectLater(
        repository.listing(match, CancelToken()),
        throwsA(isA<PricingFailure>()),
      );
    },
  );

  test(
    'one-hour freshness, forced refresh and stale fallback retain original timestamp',
    () async {
      final initial = await repository.listing(match, CancelToken());
      expect(adapter.requests.length, 3);
      now = now.add(const Duration(minutes: 59));
      await repository.listing(match, CancelToken());
      expect(adapter.requests.length, 3);
      await repository.listing(match, CancelToken(), refresh: true);
      expect(adapter.requests.length, 6);
      now = now.add(const Duration(hours: 1));
      adapter.fail = true;
      final stale = await repository.listing(match, CancelToken());
      expect(stale.stale, true);
      expect(
        stale.checkedAt,
        initial.checkedAt.add(const Duration(minutes: 59)),
      );
    },
  );

  test(
    'cache reopening and source-specific confirmed matches preserve personal data',
    () async {
      await repository.listing(match, CancelToken());
      await repository.confirm(
        game.key,
        game.title,
        match,
        storage.cacheGeneration,
      );
      await storage.preferences.put('name', 'Player');
      await storage.library.put(
        game.key,
        LibraryEntry(game: game, notes: 'Keep my notes', favorite: true),
      );
      expect(repository.mapping('igdb:4', game.title), isNull);
      expect(repository.mapping('demo:4', game.title), isNull);
      await storage.cache.close();
      storage = AppStorage(
        storage.library,
        storage.preferences,
        await Hive.openBox('cache'),
        clock: () => now,
      );
      repository = PricingRepository(storage, service);
      adapter.fail = true;
      expect(repository.mapping(game.key, game.title)?.id, '36');
      expect((await repository.listing(match, CancelToken())).offers.length, 2);
      await storage.clearCache();
      expect(repository.mapping(game.key, game.title), isNull);
      expect(storage.preferences.get('name'), 'Player');
      expect(storage.library.isOpen, true);
      expect(storage.library.get(game.key)?.notes, 'Keep my notes');
      expect(storage.library.get(game.key)?.favorite, true);
    },
  );

  test(
    'malformed cache recovers; malformed network and timeout-like failures report errors',
    () async {
      await storage.cache.put('prices:cheapshark:v1:/games:{"id":"36"}', {
        'time': now.millisecondsSinceEpoch,
        'data': {'info': 'bad'},
      });
      expect((await repository.listing(match, CancelToken())).offers.length, 2);
      adapter.malformed = true;
      await expectLater(
        repository.search('Unknown', CancelToken()),
        throwsA(isA<PricingFailure>()),
      );
      adapter.fail = false;
      adapter.timeout = true;
      await expectLater(
        repository.search('Timeout', CancelToken()),
        throwsA(isA<PricingFailure>()),
      );
      adapter.malformed = false;
      adapter.fail = true;
      adapter.timeout = false;
      await expectLater(
        repository.search('Unknown', CancelToken()),
        throwsA(isA<PricingFailure>()),
      );
    },
  );

  test(
    '429 respects Retry-After across requests and permits retry afterwards',
    () async {
      adapter.status = 429;
      await expectLater(
        repository.search('Portal', CancelToken()),
        throwsA(
          isA<PricingFailure>().having(
            (e) => e.retryAt,
            'retry time',
            now.add(const Duration(seconds: 120)),
          ),
        ),
      );
      final calls = adapter.requests.length;
      await expectLater(
        repository.search('Other', CancelToken()),
        throwsA(isA<PricingFailure>()),
      );
      expect(adapter.requests.length, calls);
      now = now.add(const Duration(seconds: 121));
      adapter.status = 200;
      expect(await repository.search('Other', CancelToken()), hasLength(1));
    },
  );

  test(
    'concurrent identical requests are coalesced and cancel only when all readers leave',
    () async {
      adapter.gate = Completer<void>();
      final firstCancel = CancelToken(), secondCancel = CancelToken();
      final first = repository.search('Portal', firstCancel);
      final firstAssertion = expectLater(first, throwsA(isA<DioException>()));
      final second = repository.search('Portal', secondCancel);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(adapter.requests.length, 1);
      firstCancel.cancel();
      await firstAssertion;
      expect(adapter.cancelled, false);
      adapter.gate!.complete();
      expect(await second, hasLength(1));
    },
  );

  test('HTTP-date Retry-After and no-offer responses are handled', () async {
    adapter.status = 429;
    adapter.retryAfter = HttpDate.format(now.add(const Duration(minutes: 3)));
    await expectLater(
      repository.search('Limited', CancelToken()),
      throwsA(
        isA<PricingFailure>().having(
          (e) => e.retryAt,
          'HTTP date',
          now.add(const Duration(minutes: 3)),
        ),
      ),
    );
    now = now.add(const Duration(minutes: 4));
    adapter.status = 200;
    adapter.listing['deals'] = [];
    expect((await repository.listing(match, CancelToken())).offers, isEmpty);
  });

  test(
    'live CheapShark smoke check',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final liveService = PricingService();
      try {
        final liveRepository = PricingRepository(storage, liveService);
        final candidates = await liveRepository.search(
          'Portal 2',
          CancelToken(),
          refresh: true,
        );
        final selected = exactPriceMatch('Portal 2', candidates);
        expect(selected, isNotNull);
        final result = await liveRepository.listing(
          selected!,
          CancelToken(),
          refresh: true,
        );
        expect(result.stale, false);
        expect(result.offers, isNotEmpty);
        expect(result.offers.any((offer) => offer.storeName == 'Steam'), true);
        expect(result.offers.first.url.host, 'www.cheapshark.com');
        expect(result.rupeeRate, isNotNull);
        expect(result.rupeeRate!.rate, greaterThan(0));
      } finally {
        liveService.dispose();
      }
    }, _LiveNetwork()),
    skip: !const bool.fromEnvironment('PRICING_LIVE'),
  );

  test(
    'clear cache while loading cannot repopulate prices or mappings',
    () async {
      adapter.gate = Completer<void>();
      final provider = PricingProvider(repository, game);
      final pending = provider.open();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await storage.clearCache();
      adapter.gate!.complete();
      await pending;
      expect(storage.cache.isEmpty, true);
      expect(repository.mapping(game.key, game.title), isNull);
      provider.dispose();
    },
  );

  test(
    'provider auto selects, persists match and ignores repeated load taps',
    () async {
      adapter.gate = Completer<void>();
      final provider = PricingProvider(repository, game);
      final pending = provider.open();
      await provider.open();
      await provider.load();
      adapter.gate!.complete();
      await pending;
      expect(provider.listing?.match.id, '36');
      expect(provider.loading, false);
      expect(repository.mapping(game.key, game.title)?.id, '36');
      expect(adapter.requests.length, 4);
      provider.dispose();
    },
  );

  test(
    'ambiguous editions require selection and unmatched results stay empty',
    () async {
      adapter.matches = [
        const PriceMatch('5', 'Portal 2 Deluxe Edition').toJson(),
      ];
      final provider = PricingProvider(repository, game);
      await provider.open();
      expect(provider.choosing, true);
      expect(provider.listing, isNull);
      expect(adapter.requests.length, 1);
      adapter.listing['info']['title'] = 'Portal 2 Deluxe Edition';
      await provider.select(provider.matches.single);
      expect(provider.listing?.match.title, 'Portal 2 Deluxe Edition');
      provider.dispose();
      adapter.matches = [];
      final empty = PricingProvider(
        repository,
        const Game(id: 7, title: 'Unmatched', source: 'rawg'),
      );
      await empty.open();
      expect(empty.matches, isEmpty);
      expect(empty.choosing, true);
      empty.dispose();
    },
  );

  test(
    'disposing cancels requests and prevents late notification or writes',
    () async {
      adapter.gate = Completer<void>();
      final provider = PricingProvider(repository, game);
      final pending = provider.open();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      provider.dispose();
      await pending;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(adapter.cancelled, true);
      expect(storage.cache.isEmpty, true);
    },
  );

  Widget host({double scale = 1, bool dark = false, GlobalKey? boundary}) =>
      Provider<PricingRepository>.value(
        value: repository,
        child: MaterialApp(
          theme: ThemeData(
            fontFamily: const bool.fromEnvironment('PRICING_PREVIEWS')
                ? 'PreviewSans'
                : null,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.cyan,
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Game details · fixture preview'),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: const StorePricesSection(game: game),
              ),
            ),
          ),
        ),
      );

  Future<void> openSection(WidgetTester tester) async {
    // Hive IO runs outside the fake widget clock.
    await tester.runAsync(() async {
      await tester.tap(find.text('Stores & prices'));
      final provider = tester
          .element(find.byType(ExpansionTile))
          .read<PricingProvider>();
      for (var i = 0; i < 100 && provider.loading; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'section fetches only when opened; stale offers lose lowest-price claims',
    (tester) async {
      await tester.pumpWidget(host());
      expect(adapter.requests, isEmpty);
      await openSection(tester);
      expect(find.text('Epic Games Store'), findsOneWidget);
      expect(find.text('Lowest among listed stores'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      now = now.add(const Duration(hours: 2));
      adapter.fail = true;
      await tester.pumpWidget(host());
      await openSection(tester);
      expect(find.textContaining('Outdated prices'), findsOneWidget);
      expect(find.text('Lowest among listed stores'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('unmatched and error states remain actionable', (tester) async {
    adapter.matches = [];
    await tester.pumpWidget(host());
    await openSection(tester);
    expect(find.text('No matching PC listing found'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(storage.clearCache);
    adapter.fail = true;
    await tester.pumpWidget(host());
    await openSection(tester);
    expect(find.text('Retry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [360.0, 1100.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('store prices layout at width $width and scale $scale', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1100);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          host(scale: scale, dark: true, boundary: boundary),
        );
        await openSection(tester);
        expect(find.text('≈ ₹425.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('PRICING_PREVIEWS') && scale == 1) {
          final render =
              boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'docs/previews/store-prices-${width.toInt()}-fixture.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
