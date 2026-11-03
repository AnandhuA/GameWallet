import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:game_atlas/core/api_service.dart';
import 'package:game_atlas/core/companion_models.dart';
import 'package:game_atlas/core/companion_repository.dart';
import 'package:game_atlas/core/game_repository.dart';
import 'package:game_atlas/core/models.dart';
import 'package:game_atlas/core/storage.dart';
import 'package:game_atlas/features/companion/companion_providers.dart';
import 'package:game_atlas/features/journal/journal_pages.dart';
import 'package:game_atlas/features/library/library_provider.dart';
import 'package:game_atlas/features/settings/settings_provider.dart';

const first = Game(
  id: 1,
  title: 'Adventure one',
  source: 'rawg',
  genres: ['Adventure'],
  platforms: ['PC'],
);
const second = Game(
  id: 2,
  title: 'Puzzle two',
  source: 'rawg',
  genres: ['Puzzle'],
  platforms: ['Android'],
);

class MemoryLibrary extends LibraryProvider {
  MemoryLibrary(super.storage);
  final values = <String, LibraryEntry>{};
  @override
  LibraryEntry? entry(Game game) => values[game.key];
  @override
  Future<void> save(LibraryEntry value) async {
    values[value.game.key] = value;
    notifyListeners();
  }

  @override
  Future<void> remove(Game game) async {
    values.remove(game.key);
    notifyListeners();
  }
}

class StarterCatalog extends GameRepository {
  bool failStrategy = true;
  StarterCatalog(AppStorage storage) : super(storage, ApiService());
  @override
  Future<CatalogFilters> filters(
    bool demo, {
    bool forceRefresh = false,
  }) async => const CatalogFilters({
    'Adventure': 'Adventure',
    'Strategy': 'Strategy',
    'Racing': 'Racing',
  }, {});
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
  }) async => CatalogResult(
    List.generate(
      3,
      (i) => Game(
        id:
            (genre == 'Strategy'
                ? 10
                : genre == 'Racing'
                ? 20
                : 0) +
            i +
            1,
        title: '$genre $i',
        source: 'rawg',
      ),
    ),
  );
  @override
  Future<(Game, bool)> detail(
    int id,
    bool demo, {
    CancelToken? cancel,
    bool forceRefresh = false,
  }) async {
    if (failStrategy && id >= 10 && id < 20) {
      throw const ApiFailure('Fixture unavailable');
    }
    return (Game(id: id, title: 'Verified $id', source: 'rawg'), false);
  }
}

void main() {
  late Directory directory;
  late AppStorage storage;
  late CompanionRepository repository;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('companion_test');
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
    repository = CompanionRepository(storage);
  });
  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
  test(
    'Grid columns persist independently and reject unsupported density',
    () async {
      final settings = SettingsProvider(
        storage,
        GameRepository(storage, ApiService()),
      );
      expect(settings.gridColumns('explore'), 0);
      await settings.setGridColumns('explore', 3);
      await settings.setLibraryLayout('list');
      await settings.setGridColumns('library', 5);
      expect(settings.libraryLayout, 'compact');
      final reopened = SettingsProvider(
        storage,
        GameRepository(storage, ApiService()),
      );
      expect(reopened.gridColumns('explore'), 3);
      expect(reopened.gridColumns('library'), 5);
      await expectLater(
        settings.setGridColumns('explore', 6),
        throwsArgumentError,
      );
      expect(settings.gridColumns('explore'), 3);
      await settings.setGridColumns('explore', 0);
      expect(settings.gridColumns('explore'), 0);
    },
  );

  test('Library view style persists and rejects unsupported values', () async {
    final settings = SettingsProvider(storage, StarterCatalog(storage));
    expect(settings.libraryLayout, 'compact');
    for (final value in ['grid', 'list', 'compact']) {
      await settings.setLibraryLayout(value);
      expect(
        SettingsProvider(storage, StarterCatalog(storage)).libraryLayout,
        value,
      );
      expect(storage.preferences.get('libraryLayout'), value);
    }
    await expectLater(
      settings.setLibraryLayout('unknown'),
      throwsArgumentError,
    );
    expect(settings.libraryLayout, 'compact');
    settings.dispose();
  });
  test(
    'Played history survives replay and stays separate from discovery and source modes',
    () async {
      final library = LibraryProvider(storage);
      await library.save(
        LibraryEntry(game: first, status: LibraryStatus.completed),
      );
      expect(library.hasPlayed(first), true);
      expect(library.playedEntries(false).single.game.key, first.key);
      expect(library.playingEntries(false), isEmpty);
      await library.setStatus(first, LibraryStatus.playing);
      expect(library.hasPlayed(first), true);
      expect(library.playingEntries(false).single.game.key, first.key);
      expect(library.playedEntries(false).single.completedRuns, 1);
      expect(library.playedEntries(true), isEmpty);
      await library.setStatus(second, LibraryStatus.playing);
      expect(library.hasPlayed(second), false);
    },
  );
  test(
    'Saved is independent of playing and completion history persists',
    () async {
      final library = LibraryProvider(storage);
      await library.toggleSaved(first);
      expect(library.entry(first)!.bookmarked, true);
      await library.setStatus(first, LibraryStatus.playing);
      await library.toggleSaved(first);
      expect(library.entry(first)!.status, LibraryStatus.playing);
      expect(library.entry(first)!.bookmarked, false);
      await library.save(
        LibraryEntry(
          game: first,
          status: LibraryStatus.completed,
          bookmarked: true,
          completedRuns: 2,
        ),
      );
      await library.setStatus(first, LibraryStatus.playing);
      await library.favorite(first);
      await storage.library.close();
      final reopened = await Hive.openBox<LibraryEntry>('library');
      expect(reopened.get(first.key)!.completedRuns, 2);
      expect(reopened.get(first.key)!.bookmarked, true);
      expect(reopened.get(first.key)!.status, LibraryStatus.playing);
      expect(reopened.get(first.key)!.favorite, true);
    },
  );
  test('Older library records keep saved status and known completion', () {
    final data =
        LibraryEntry(game: first, status: LibraryStatus.completed).toJson()
          ..remove('bookmarked')
          ..remove('completedRuns');
    final restored = LibraryEntry.fromJson(data);
    expect(restored.bookmarked, true);
    expect(restored.completedRuns, 1);
  });
  test(
    'Journal import is lossless, repeatable, and does not resurrect deleted reviews',
    () async {
      await storage.library.put(
        first.key,
        LibraryEntry(game: first, notes: 'A legacy note', personalRating: 9),
      );
      await repository.prepare();
      await repository.prepare();
      final journal = JournalProvider(repository);
      final imported = journal.entries(false).single;
      expect(imported.rating, 4.5);
      expect(imported.notes, 'A legacy note');
      expect(imported.playedOn, null);
      expect(imported.imported, true);
      expect(repository.box.containsKey('backup:import:${first.key}'), true);
      await storage.clearCache();
      expect(journal.entries(false), hasLength(1));
      await journal.delete(imported.id);
      await repository.prepare();
      expect(journal.entries(false), isEmpty);
      expect(storage.library.get(first.key)!.notes, 'A legacy note');
    },
  );
  test(
    'Migration failure retains original data and leaves its marker incomplete',
    () async {
      await storage.library.put(
        first.key,
        LibraryEntry(game: first, notes: 'Original'),
      );
      await repository.put(
        'journal',
        'import:${first.key}',
        PlaythroughEntry(id: 'wrong', game: second, notes: 'Wrong').toJson(),
      );
      await expectLater(repository.prepare(), throwsStateError);
      expect(storage.library.get(first.key)!.notes, 'Original');
      expect(repository.box.get('migrated:${first.key}'), null);
    },
  );
  test(
    'LineUp ordering, source IDs, cloning, favorites and progress survive reopening',
    () async {
      final lineups = LineUpProvider(repository);
      final library = LibraryProvider(storage);
      const legacy = Game(id: 1, title: 'Other catalog');
      await lineups.save(
        const GameLineUp(
          id: 'list',
          title: 'My list',
          games: [second, first, first, legacy],
          favorite: true,
          coverKey: 'rawg:2',
        ),
      );
      expect(lineups.byId('list')!.games.map((g) => g.key), [
        'rawg:2',
        'rawg:1',
        'igdb:1',
      ]);
      await library.save(
        LibraryEntry(game: first, status: LibraryStatus.completed),
      );
      expect(lineups.completed(lineups.byId('list')!, library), 1);
      final copy = await lineups.clone(lineups.byId('list')!);
      await lineups.save(copy.copy(games: [first, second]));
      expect(lineups.byId('list')!.games.first.key, second.key);
      await storage.personal!.close();
      final reopened = await Hive.openBox('personal');
      final again = LineUpProvider(
        CompanionRepository(
          AppStorage(
            storage.library,
            storage.preferences,
            storage.cache,
            personal: reopened,
          ),
        ),
      );
      expect(again.byId('list')!.favorite, true);
      expect(again.byId(copy.id)!.games.first.key, first.key);
      await again.delete(copy.id);
      expect(again.byId('list'), isNotNull);
    },
  );
  test(
    'Starter lists store only verified records and retry incomplete lists',
    () async {
      final p = LineUpProvider(repository);
      final catalog = StarterCatalog(storage);
      await p.loadStarters(catalog, false);
      expect(p.entries(false), hasLength(2));
      expect(p.error, contains('Strategy'));
      expect(
        p
            .entries(false)
            .every((l) => l.games.every((g) => g.title.startsWith('Verified'))),
        true,
      );
      catalog.failStrategy = false;
      await p.loadStarters(catalog, false);
      expect(p.entries(false), hasLength(3));
      expect(p.error, null);
      await p.loadStarters(catalog, false);
      expect(p.entries(false), hasLength(3));
    },
  );
  test(
    'Dated reviews retain half stars, separate replays, and reject invalid ratings',
    () async {
      final journal = JournalProvider(repository);
      await journal.save(
        PlaythroughEntry(
          id: 'one',
          game: first,
          rating: 3.5,
          playedOn: DateTime(2025, 1, 1),
          review: 'First run',
          updatedAt: DateTime(2025, 1, 1),
        ),
      );
      await journal.save(
        PlaythroughEntry(
          id: 'two',
          game: first,
          rating: 4.5,
          playedOn: DateTime(2026, 1, 1),
          reactions: ['Loved it'],
          tags: ['replay'],
        ),
      );
      expect(journal.entries(false, gameKey: first.key), hasLength(2));
      expect(journal.latest(first)!.rating, 4.5);
      await expectLater(
        journal.save(PlaythroughEntry(id: 'bad', game: first, rating: 1.2)),
        throwsArgumentError,
      );
      await journal.delete('two');
      expect(journal.latest(first)!.review, 'First run');
    },
  );
  test(
    'Calendar completion is independent from game completion and persists',
    () async {
      final plans = CalendarProvider(repository);
      await plans.save(
        PlaySessionPlan(
          id: 'plan',
          game: first,
          scheduled: DateTime(2026, 12, 1, 19, 30),
          hasTime: true,
          notes: 'A short session',
        ),
      );
      await plans.save(plans.entries(false).single.withCompleted(true));
      expect(storage.library.get(first.key), null);
      final restored = CalendarProvider(
        CompanionRepository(storage),
      ).entries(false).single;
      expect(restored.scheduled.hour, 19);
      expect(restored.hasTime, true);
      expect(restored.completed, true);
      await plans.delete('plan');
      expect(plans.entries(false), isEmpty);
    },
  );
  test(
    'Hidden games are separate from Dropped and Smart Pick filters honestly',
    () async {
      final hidden = DiscoveryPreferencesProvider(repository);
      final library = LibraryProvider(storage);
      await hidden.setHidden(first, true);
      expect(library.entry(first), null);
      expect(smartCandidates([first, second], library, hidden), [second]);
      await hidden.setHidden(first, false);
      await library.save(
        LibraryEntry(game: second, status: LibraryStatus.dropped),
      );
      expect(
        smartCandidates(
          [first, second],
          library,
          hidden,
          platform: 'PC',
          mood: 'Story',
        ),
        [first],
      );
      expect(
        smartCandidates([first, second], library, hidden, platform: 'Android'),
        isEmpty,
      );
      expect(
        smartCandidates(
          [first, second],
          library,
          hidden,
          unfinished: false,
          preferredGenres: ['Puzzle'],
        ).first,
        second,
      );
    },
  );
  test(
    'Wheel freezes candidates and the angle identifies the displayed winner',
    () {
      final wheel = WheelProvider(random: Random(42));
      wheel.replace([first, second]);
      for (var i = 0; i < 20; i++) {
        expect(wheel.begin(), true);
        final frozen = wheel.frozen;
        wheel.replace([first]);
        expect(wheel.candidates, hasLength(2));
        expect(() => frozen.add(first), throwsUnsupportedError);
        final angle = (-wheel.targetAngle) % (2 * pi);
        final visibleIndex = (angle / (2 * pi / frozen.length)).floor();
        expect(visibleIndex, wheel.selectedIndex);
        wheel.finish();
        expect(wheel.winner!.key, frozen[visibleIndex].key);
      }
    },
  );
  testWidgets(
    'Quick completion cancel and skip do not invent journal reviews',
    (tester) async {
      final library = MemoryLibrary(storage);
      final journal = JournalProvider(repository);
      await tester.runAsync(
        () => library.save(
          LibraryEntry(game: first, status: LibraryStatus.wantToPlay),
        ),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LibraryProvider>.value(value: library),
            ChangeNotifierProvider.value(value: journal),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => completeGame(context, first),
                  child: const Text('Complete'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(library.entry(first)!.status, LibraryStatus.wantToPlay);
      expect(journal.entries(false), isEmpty);
      await tester.tap(find.text('Complete'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Complete without review'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(library.entry(first)!.status, LibraryStatus.completed);
      expect(journal.entries(false), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
