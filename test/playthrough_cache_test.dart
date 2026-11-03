import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/core/storage.dart';
import 'package:game_atlas/core/api_service.dart';
import 'package:game_atlas/core/game_repository.dart';
import 'package:game_atlas/core/image_cache_service.dart';
import 'package:game_atlas/core/companion_repository.dart';
import 'package:game_atlas/features/library/library_provider.dart';
import 'package:game_atlas/features/library/playthrough_dates.dart';
import 'package:game_atlas/features/companion/companion_providers.dart';
import 'package:game_atlas/features/journal/journal_pages.dart';

const game = Game(id: 77, title: 'Date fixture', source: 'rawg');

class MediaAdapter implements HttpClientAdapter {
  final Uint8List png;
  int calls = 0, active = 0, peak = 0;
  bool fail = false, corrupt = false;
  Completer<void>? gate;
  MediaAdapter(this.png);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    active++;
    peak = max(peak, active);
    try {
      if (gate != null) {
        await Future.any([
          gate!.future,
          if (cancelFuture != null)
            cancelFuture.then((_) => throw StateError('Cancelled')),
        ]);
      }
      return ResponseBody.fromBytes(
        corrupt ? [1, 2, 3] : png,
        fail ? 503 : 200,
        headers: {
          'content-type': ['image/png'],
        },
      );
    } finally {
      active--;
    }
  }

  @override
  void close({bool force = false}) {}
}

class CatalogAdapter implements HttpClientAdapter {
  int calls = 0;
  Completer<void>? gate;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (gate != null) await gate!.future;
    return ResponseBody.fromString(
      '{"results":[{"id":77,"name":"Cached fixture","rating":4,"ratings_count":2}],"next":null}',
      200,
      headers: {
        'content-type': ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FailingJournal extends JournalProvider {
  FailingJournal(super.repository);
  @override
  Future<void> save(entry) async => throw StateError('Disk fixture failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late AppStorage storage;
  late DateTime now;
  setUp(() async {
    now = DateTime(2026, 10, 30, 23, 50);
    directory = await Directory.systemTemp.createTemp('dates_cache');
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
      clock: () => now,
    );
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'Calendar days include both dates across DST, month/year and leap days',
    () {
      expect(
        inclusiveDays(DateTime(2026, 3, 8, 23), DateTime(2026, 3, 9, 1)),
        2,
      );
      expect(inclusiveDays(DateTime(2025, 12, 31), DateTime(2026, 1, 1)), 2);
      expect(inclusiveDays(DateTime(2024, 2, 28), DateTime(2024, 3, 1)), 3);
      expect(inclusiveDays(now, now), 1);
    },
  );
  test(
    'Start is idempotent, unfinished resumes, completions deduplicate and replays retain dates',
    () async {
      final library = LibraryProvider(storage, clock: () => now);
      await library.startPlaying(game);
      final first = library.active(game)!;
      await library.startPlaying(game);
      expect(library.active(game)!.id, first.id);
      expect(library.timing(game), startsWith('Day 1'));
      await library.setStatus(game, LibraryStatus.dropped);
      now = DateTime(2026, 11, 1);
      await library.startPlaying(game);
      expect(library.active(game)!.id, first.id);
      expect(library.timing(game), startsWith('Day 3'));
      final draft = library.completionDraft(game);
      await library.completePlaythrough(game, draft);
      await library.completePlaythrough(game, draft);
      expect(library.entry(game)!.completedRuns, 1);
      expect(library.timing(game), 'Completed in 3 days');
      expect(library.completedDays(game), 3);
      await library.startPlaying(game);
      expect(library.active(game)!.id, isNot(first.id));
      expect(library.completedTiming(game), 'Completed in 3 days');
      expect(library.entry(game)!.playthroughs, hasLength(2));
      expect(library.hasPlayed(game), true);
      await library.favorite(game);
      await library.toggleSaved(game);
      expect(library.entry(game)!.playthroughs, hasLength(2));
      library.dispose();
    },
  );
  test(
    'Legacy dates remain unknown and edits preserve counts/status across Hive reopening',
    () async {
      final library = LibraryProvider(storage, clock: () => now);
      await library.save(
        LibraryEntry(
          game: game,
          status: LibraryStatus.completed,
          completedRuns: 4,
        ),
      );
      expect(library.timing(game), 'Dates not recorded');
      expect(library.completedDays(game), isNull);
      await library.updateDates(
        game,
        GamePlaythrough(
          id: 'legacy',
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 2),
          completed: true,
        ),
      );
      expect(library.entry(game)!.completedRuns, 4);
      await expectLater(
        library.updateDates(
          game,
          GamePlaythrough(
            id: 'legacy',
            startDate: DateTime(2026, 11, 1),
            completed: true,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        library.updateDates(
          game,
          GamePlaythrough(
            id: 'legacy',
            startDate: DateTime(2026, 10, 3),
            endDate: DateTime(2026, 10, 2),
            completed: true,
          ),
        ),
        throwsArgumentError,
      );
      library.dispose();
      await storage.library.close();
      final reopened = await Hive.openBox<LibraryEntry>('library');
      expect(reopened.get(game.key)!.playthroughs.single.days(now), 2);
      expect(reopened.get(game.key)!.completedRuns, 4);
    },
  );
  test(
    'Image bytes persist, deduplicate and fall back to stale copies',
    () async {
      final adapter = MediaAdapter(
        await File('assets/art/1.png').readAsBytes(),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final cache = ImageCacheService(
        storage.images,
        dio: dio,
        clock: () => now,
      );
      final results = await Future.wait([
        cache.load('https://media.test/a.png'),
        cache.load('https://media.test/a.png'),
      ]);
      expect(adapter.calls, 1);
      expect(results.first, results.last);
      expect(cache.count, 1);
      cache.dispose();
      await storage.images!.close();
      final reopened = await Hive.openBox('images');
      final restored = ImageCacheService(reopened, dio: dio, clock: () => now);
      expect(restored.peek('https://media.test/a.png'), isNotNull);
      now = now.add(const Duration(days: 31));
      adapter.fail = true;
      expect(await restored.load('https://media.test/a.png'), results.first);
      await restored.clear();
      expect(restored.count, 0);
      restored.dispose();
      dio.close();
    },
  );
  test(
    'Image LRU eviction and invalid image rejection keep personal records',
    () async {
      final adapter = MediaAdapter(
        await File('assets/art/1.png').readAsBytes(),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final cache = ImageCacheService(
        storage.images,
        dio: dio,
        clock: () => now,
        maxEntries: 1,
      );
      await storage.library.put(
        game.key,
        LibraryEntry(game: game, notes: 'Keep'),
      );
      await cache.load('https://media.test/a.png');
      now = now.add(const Duration(seconds: 1));
      await cache.load('https://media.test/b.png');
      expect(cache.peek('https://media.test/a.png'), null);
      expect(cache.count, 1);
      adapter.corrupt = true;
      await expectLater(
        cache.load('https://media.test/bad.png'),
        throwsA(anything),
      );
      expect(cache.count, 1);
      await cache.clear();
      await storage.clearCache();
      expect(storage.library.get(game.key)!.notes, 'Keep');
      cache.dispose();
      dio.close();
    },
  );
  test(
    'Downloads obey concurrency three and clearing prevents late cache writes',
    () async {
      final adapter = MediaAdapter(await File('assets/art/1.png').readAsBytes())
        ..gate = Completer<void>();
      final dio = Dio()..httpClientAdapter = adapter;
      final cache = ImageCacheService(storage.images, dio: dio);
      final pending = Future.wait(
        List.generate(
          5,
          (i) => cache
              .load('https://media.test/$i.png')
              .then<Object>((v) => v, onError: (Object e) => e),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(adapter.calls, 3);
      expect(adapter.peak, 3);
      await cache.clear();
      adapter.gate!.complete();
      await pending;
      expect(cache.count, 0);
      expect(adapter.calls, 3);
      cache.dispose();
      dio.close();
    },
  );
  test(
    'Force refresh, malformed metadata recovery and clearing during a request',
    () async {
      final adapter = CatalogAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://catalog.test'))
        ..httpClientAdapter = adapter;
      final repo = GameRepository(
        storage,
        ApiService(client: dio, apiKey: () => 'fixture'),
      );
      await repo.games(demo: false);
      await repo.games(demo: false);
      expect(adapter.calls, 1);
      await repo.games(demo: false, forceRefresh: true);
      expect(adapter.calls, 2);
      await storage.cache.put(storage.cache.keys.single, {
        'time': now.millisecondsSinceEpoch,
        'data': {
          'games': [
            {'oops': 1},
          ],
        },
      });
      await repo.games(demo: false);
      expect(adapter.calls, 3);
      adapter.gate = Completer<void>();
      final load = repo.games(demo: false, forceRefresh: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await storage.clearCache();
      adapter.gate!.complete();
      await load;
      expect(storage.cache.isEmpty, true);
      dio.close();
    },
  );
  test(
    'Unstarted completions and older maps do not fabricate start dates',
    () async {
      final library = LibraryProvider(storage, clock: () => now);
      await library.completePlaythrough(game, library.completionDraft(game));
      expect(library.entry(game)!.playthroughs.single.startDate, null);
      expect(library.timing(game), 'Dates not recorded');
      final legacy = library.entry(game)!.toJson()
        ..remove('playthroughs')
        ..remove('activePlaythroughId');
      expect(LibraryEntry.fromJson(legacy).playthroughs, isEmpty);
      expect(LibraryEntry.fromJson(legacy).completedRuns, 1);
      library.dispose();
    },
  );
  test(
    'Image byte budget evicts artwork while clearing preserves run dates',
    () async {
      final png = await File('assets/art/1.png').readAsBytes();
      final adapter = MediaAdapter(png);
      final dio = Dio()..httpClientAdapter = adapter;
      final cache = ImageCacheService(
        storage.images,
        dio: dio,
        clock: () => now,
        maxBytes: png.length + 10,
      );
      final library = LibraryProvider(storage, clock: () => now);
      await library.startPlaying(game);
      final id = library.active(game)!.id;
      await cache.load('https://media.test/a.png');
      now = now.add(const Duration(seconds: 1));
      await cache.load('https://media.test/b.png');
      expect(cache.count, 1);
      expect(cache.bytes, lessThanOrEqualTo(png.length + 10));
      await cache.clear();
      await storage.clearCache();
      expect(library.active(game)!.id, id);
      library.dispose();
      cache.dispose();
      dio.close();
    },
  );
  test(
    'Failed automatic artwork caching never blocks a personal status save',
    () async {
      final adapter = MediaAdapter(await File('assets/art/1.png').readAsBytes())
        ..fail = true;
      final dio = Dio()..httpClientAdapter = adapter;
      final cache = ImageCacheService(storage.images, dio: dio);
      final library = LibraryProvider(
        storage,
        imageCache: cache,
        clock: () => now,
      );
      const withCover = Game(
        id: 88,
        title: 'Network failure fixture',
        source: 'rawg',
        cover: 'https://media.test/cover.png',
      );
      await library.startPlaying(withCover);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(library.entry(withCover)!.status, LibraryStatus.playing);
      expect(library.active(withCover)!.startDate, calendarDate(now));
      expect(cache.count, 0);
      library.dispose();
      cache.dispose();
      dio.close();
    },
  );
  testWidgets(
    'Invalid dates stay editable at enlarged text without changing personal data',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final library = LibraryProvider(storage, clock: () => now);
      await tester.pumpWidget(
        ChangeNotifierProvider<LibraryProvider>.value(
          value: library,
          child: MaterialApp(
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(
                c,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<CompletionChoice>(
                    context: c,
                    builder: (_) => PlaythroughDatesDialog(
                      initial: GamePlaythrough(
                        id: 'test',
                        startDate: calendarDate(now),
                        endDate: DateTime(2026, 10, 29),
                        completed: true,
                      ),
                    ),
                  ),
                  child: const Text('Dates'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Dates'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save dates'));
      await tester.tap(find.text('Save dates'));
      await tester.pumpAndSettle();
      expect(
        find.text('End date must be on or after start date.'),
        findsOneWidget,
      );
      expect(storage.library.isEmpty, true);
      expect(tester.takeException(), null);
      await tester.pumpWidget(const SizedBox());
      library.dispose();
    },
  );
  testWidgets(
    'Completion cancellation, review cancellation and write failure leave the original run intact',
    (tester) async {
      final library = LibraryProvider(storage, clock: () => now);
      await tester.runAsync(() => library.startPlaying(game));
      final original = library.entry(game)!.toJson();
      final journal = FailingJournal(CompanionRepository(storage));
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LibraryProvider>.value(value: library),
            ChangeNotifierProvider<JournalProvider>.value(value: journal),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => completeGame(c, game),
                  child: const Text('Finish'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(library.entry(game)!.toJson(), original);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add review'));
      await tester.tap(find.text('Add review'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(library.entry(game)!.toJson(), original);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add review'));
      await tester.tap(find.text('Add review'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Save'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(library.entry(game)!.toJson(), original);
      expect(journal.entries(false), isEmpty);
      expect(find.textContaining('Could not save'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      library.dispose();
      journal.dispose();
    },
  );
  testWidgets(
    'Legacy replay date editing keeps unknown active dates separate',
    (tester) async {
      final library = LibraryProvider(storage, clock: () => now);
      await tester.runAsync(
        () => library.save(
          LibraryEntry(
            game: game,
            status: LibraryStatus.playing,
            completedRuns: 2,
          ),
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<LibraryProvider>.value(
          value: library,
          child: MaterialApp(
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => editPlaythroughDates(c, game),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Start date'), findsOneWidget);
      expect(find.text('End date'), findsNothing);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(library.entry(game)!.playthroughs, isEmpty);
      expect(library.entry(game)!.completedRuns, 2);
      await tester.pumpWidget(const SizedBox());
      library.dispose();
    },
  );
  testWidgets('Midnight and resume update the calendar counter', (
    tester,
  ) async {
    final library = LibraryProvider(
      storage,
      clock: () => now,
      observeClock: true,
    );
    await tester.runAsync(() => library.startPlaying(game));
    var notifications = 0;
    library.addListener(() => notifications++);
    now = DateTime(2026, 10, 31, 0, 1);
    await tester.pump(const Duration(minutes: 11));
    expect(library.timing(game), startsWith('Day 2'));
    expect(notifications, greaterThan(0));
    now = DateTime(2026, 11, 2);
    library.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(library.timing(game), startsWith('Day 4'));
    library.dispose();
  });
}
