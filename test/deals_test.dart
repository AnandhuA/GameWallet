import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/core/storage.dart';
import 'package:game_atlas/features/deals/deal_record.dart';
import 'package:game_atlas/features/deals/deals_service.dart';
import 'package:game_atlas/features/deals/deals_repository.dart';
import 'package:game_atlas/features/deals/deals_provider.dart';
import 'package:game_atlas/features/deals/deals_page.dart';
import 'package:game_atlas/shared/app_theme.dart';

Map<String, dynamic> entry({
  String title = 'Fixture adventure',
  String date = '2026-10-29',
  String platform = 'pc',
}) => {
  'gameTitle': title,
  'freeDate': date,
  'platform': platform,
  'epicStoreLink': 'https://store.epicgames.com/en-US/p/fixture',
  'epicRating': 4.5,
  'metacriticScore': 83,
};

class _LiveNetwork extends HttpOverrides {}

class FixtureService extends DealsService {
  int calls = 0;
  Future<dynamic> Function(CancelToken)? response;
  @override
  Future<dynamic> fetch(CancelToken cancel) async {
    calls++;
    return response == null ? [entry()] : await response!(cancel);
  }
}

void main() {
  late Directory directory;
  late AppStorage storage;
  late FixtureService service;
  late DealsRepository repository;
  var now = DateTime(2026, 11, 4, 12);
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wallet_deals_');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(LibraryEntryAdapter());
    }
    now = DateTime(2026, 11, 4, 12);
    storage = AppStorage(
      await Hive.openBox<LibraryEntry>('library'),
      await Hive.openBox('prefs'),
      await Hive.openBox('cache'),
      personal: await Hive.openBox('personal'),
      clock: () => now,
    );
    service = FixtureService();
    repository = DealsRepository(storage, service);
  });
  tearDown(() async {
    service.dispose();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test(
    'parser validates dates, links, scores, duplicates and platform occurrences',
    () {
      final records = parseEpicRecords([
        entry(),
        entry(),
        entry(platform: 'android'),
        entry(date: '2026-10-22'),
        {
          ...entry(),
          'epicStoreLink': 'https://store.epicgames.com.evil.test/p/x',
        },
        entry(date: '2026-02-30'),
        null,
        {'gameTitle': 'Missing fields'},
        {
          ...entry(title: 'Unknown'),
          'platform': '',
          'epicRating': 0,
          'metacriticScore': 0,
        },
      ]);
      expect(records.length, 4);
      expect(records.last.dateLabel, '2026-10-22');
      expect(records.singleWhere((e) => e.title == 'Unknown').rating, isNull);
      expect(
        records.singleWhere((e) => e.title == 'Unknown').platform,
        'unknown',
      );
      expect(
        DealRecord.safeStoreUrl('http://store.epicgames.com/p/x'),
        isFalse,
      );
      expect(
        DealRecord.safeStoreUrl('https://user@store.epicgames.com/p/x'),
        isFalse,
      );
      expect(
        DealRecord.safeStoreUrl('https://store.epicgames.com:444/p/x'),
        isFalse,
      );
      expect(() => parseEpicRecords({'broken': true}), throwsFormatException);
      expect(() => parseEpicRecords([null]), throwsFormatException);
      expect(parseEpicRecords([]), isEmpty);
    },
  );

  test(
    'fresh cache, exact expiry, forced refresh and offline fallback',
    () async {
      await repository.load(CancelToken());
      await repository.load(CancelToken());
      expect(service.calls, 1);
      await repository.load(CancelToken(), refresh: true);
      expect(service.calls, 2);
      now = now.add(const Duration(hours: 1));
      service.response = (_) async => throw const SocketException('Offline');
      final stale = await repository.load(CancelToken());
      expect(stale.stale, isTrue);
      expect(stale.records.single.title, 'Fixture adventure');
      expect(service.calls, 3);
      expect(stale.fetchedAt, now.subtract(const Duration(hours: 1)));
    },
  );

  test(
    'malformed cache recovers, invalid feed and rate errors do not replace cache',
    () async {
      await storage.cache.put(DealsRepository.cacheKey, {
        'time': 'bad',
        'data': null,
      });
      expect((await repository.load(CancelToken())).records, hasLength(1));
      service.response = (_) async => {'invalid': true};
      expect(
        (await repository.load(CancelToken(), refresh: true)).stale,
        isTrue,
      );
      service.response = (_) async => throw DioException(
        requestOptions: RequestOptions(),
        response: Response(requestOptions: RequestOptions(), statusCode: 429),
      );
      expect(
        (await repository.load(CancelToken(), refresh: true)).stale,
        isTrue,
      );
      await storage.clearCache();
      await expectLater(
        repository.load(CancelToken()),
        throwsA(isA<DioException>()),
      );
    },
  );

  test(
    'clearing during a request prevents cache resurrection and preserves personal records',
    () async {
      await storage.personal!.put('lineup:legacy', {'title': 'Keep my list'});
      await storage.preferences.put('displayName', 'Player');
      final pending = Completer<dynamic>();
      service.response = (_) => pending.future;
      final load = repository.load(CancelToken());
      await storage.clearCache();
      pending.complete([entry()]);
      await load;
      expect(storage.cache.isEmpty, isTrue);
      expect(storage.personal!.get('lineup:legacy')['title'], 'Keep my list');
      expect(storage.preferences.get('displayName'), 'Player');
    },
  );

  test('feed cache survives Hive reopening', () async {
    await repository.load(CancelToken());
    await storage.cache.close();
    final again = AppStorage(
      storage.library,
      storage.preferences,
      await Hive.openBox('cache'),
      clock: () => now,
    );
    final result = await DealsRepository(again, service).load(CancelToken());
    expect(result.records, hasLength(1));
    expect(service.calls, 1);
  });

  test(
    'provider deduplicates loads, ignores stale responses, filters and disposes safely',
    () async {
      final p = DealsProvider(repository);
      final first = Completer<dynamic>();
      service.response = (_) => first.future;
      final old = p.load();
      await p.load();
      expect(service.calls, 1);
      service.response = (_) async => [
        entry(title: 'New game'),
        entry(platform: 'ios'),
      ];
      await p.load(refresh: true);
      first.complete([entry(title: 'Old game')]);
      await old;
      expect(p.snapshot!.records.any((e) => e.title == 'Old game'), isFalse);
      p.filter(text: ' new ', platformValue: 'pc');
      expect(p.visible.single.title, 'New game');
      p.filter(platformValue: 'ios');
      expect(p.visible, isEmpty);
      p.dispose();
      final second = Completer<dynamic>();
      service.response = (_) => second.future;
      final disposed = DealsProvider(repository);
      final request = disposed.load(refresh: true);
      disposed.dispose();
      second.complete([entry()]);
      await request;
    },
  );

  test(
    'legacy feed cache refreshes missing Steam links and stays usable offline',
    () async {
      await storage.remember(DealsRepository.legacyCacheKey, [entry()]);
      service.response = (_) async => [
        {...entry(), 'steamUrl': 'https://store.steampowered.com/app/42/'},
      ];
      final fresh = await repository.load(CancelToken());
      expect(service.calls, 1);
      expect(fresh.records.single.steamAppId, '42');
      expect(storage.cache.containsKey(DealsRepository.cacheKey), isTrue);
      await storage.cache.delete(DealsRepository.cacheKey);
      service.response = (_) async => throw const SocketException('Offline');
      expect((await repository.load(CancelToken())).stale, isTrue);
    },
  );

  test(
    'live Epic giveaway feed smoke check',
    () => HttpOverrides.runWithHttpOverrides(() async {
      final live = DealsService();
      try {
        final records = parseEpicRecords(await live.fetch(CancelToken()));
        expect(records, isNotEmpty);
        expect(
          records.every((e) => DealRecord.safeStoreUrl(e.storeUrl)),
          isTrue,
        );
      } finally {
        live.dispose();
      }
    }, _LiveNetwork()),
    skip: !const bool.fromEnvironment('DEALS_LIVE'),
  );

  for (final appearance in ['dark', 'light', 'amoled']) {
    for (final width in [390.0, 1280.0]) {
      testWidgets(
        'Deals $appearance search, filters and readable states at $width / 200%',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = DealsProvider(repository)
            ..snapshot = DealsSnapshot(
              parseEpicRecords([
                entry(),
                entry(platform: 'android', title: 'Mobile fixture'),
              ]),
              now,
              stale: true,
            );
          await tester.pumpWidget(
            ChangeNotifierProvider.value(
              value: p,
              child: MaterialApp(
                theme: WalletTheme.build(
                  appearance == 'light' ? Brightness.light : Brightness.dark,
                  const Color(0xFF5CD0C6),
                  amoled: appearance == 'amoled',
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: child!,
                ),
                home: const Scaffold(body: DealsPage()),
              ),
            ),
          );
          await tester.scrollUntilVisible(
            find.textContaining('Offline / outdated'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.textContaining('Offline / outdated'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.byType(TextField),
            -180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(find.byType(TextField), 'not a match');
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('No matching giveaways'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('No matching giveaways'), findsOneWidget);
          await tester.scrollUntilVisible(
            find.byType(TextField),
            -180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(find.byType(TextField), '');
          await tester.tap(find.text('Android').first);
          await tester.pumpAndSettle();
          expect(p.visible.single.title, 'Mobile fixture');
          await tester.scrollUntilVisible(
            find.text('Check on Epic'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Mobile fixture'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        },
      );
    }
  }
}
