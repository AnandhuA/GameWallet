import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../core/models.dart';
import '../../core/storage.dart';
import '../../core/image_cache_service.dart';

class LibraryProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AppStorage storage;
  final ImageCacheService? imageCache;
  final DateTime Function() clock;
  Timer? _midnight;
  int _ids = 0;
  final bool observeClock;
  LibraryProvider(
    this.storage, {
    this.imageCache,
    DateTime Function()? clock,
    this.observeClock = false,
  }) : clock = clock ?? DateTime.now {
    if (observeClock) {
      WidgetsBinding.instance.addObserver(this);
      _schedule();
    }
    for (final e in storage.library.values.where(
      (e) => e.bookmarked || e.status == LibraryStatus.playing,
    )) {
      imageCache?.prefetch(e.game);
    }
  }
  DateTime get today => calendarDate(clock());
  void _schedule() {
    _midnight?.cancel();
    final now = clock(),
        next = DateTime(clock().year, clock().month, clock().day + 1);
    _midnight = Timer(
      next.difference(now) + const Duration(milliseconds: 50),
      () {
        notifyListeners();
        _schedule();
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      notifyListeners();
      _schedule();
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    if (observeClock) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  LibraryEntry? entry(Game game) => storage.library.get(game.key);
  List<LibraryEntry> entries(bool demo) =>
      storage.library.values.where((e) => e.game.demo == demo).toList();
  bool excludedFromDiscovery(Game game) =>
      hasPlayed(game) || entry(game)?.status == LibraryStatus.playing;

  bool hasPlayed(Game game) {
    final value = entry(game);
    return value?.status == LibraryStatus.completed ||
        (value?.completedRuns ?? 0) > 0;
  }

  List<LibraryEntry> playingEntries(bool demo) =>
      entries(demo).where((e) => e.status == LibraryStatus.playing).toList();
  List<LibraryEntry> playedEntries(bool demo) =>
      entries(demo).where((e) => hasPlayed(e.game)).toList();
  List<LibraryEntry> savedEntries(bool demo) => entries(
    demo,
  ).where((e) => e.bookmarked || e.status == LibraryStatus.wantToPlay).toList();
  GamePlaythrough? active(Game game) {
    final e = entry(game);
    return e?.playthroughs
        .where((r) => r.id == e.activePlaythroughId)
        .firstOrNull;
  }

  int? completedDays(Game game) {
    final run = entry(game)?.playthroughs.where((r) => r.completed).lastOrNull;
    return run?.days(today);
  }

  String? completedTiming(Game game) {
    final days = completedDays(game);
    return days == null
        ? null
        : 'Completed in $days ${days == 1 ? 'day' : 'days'}';
  }

  String timing(Game game) {
    final value = entry(game);
    final run =
        active(game) ??
        (value?.status == LibraryStatus.playing
            ? null
            : value?.playthroughs.lastOrNull);
    if (run == null) return 'Dates not recorded';
    final days = run.days(today);
    if (days == null) return 'Dates not recorded';
    return run.completed
        ? 'Completed in $days ${days == 1 ? 'day' : 'days'}'
        : 'Day $days · started ${dateKey(run.startDate!)}';
  }

  LibraryEntry _changed(Game game, Map<String, dynamic> changes) =>
      LibraryEntry.fromJson({
        ...(entry(game) ?? LibraryEntry(game: game, bookmarked: false))
            .toJson(),
        'game': game.toJson(),
        'updated': clock().toIso8601String(),
        ...changes,
      });
  Future<void> save(LibraryEntry value) async {
    await storage.library.put(value.game.key, value);
    if (value.bookmarked || value.status == LibraryStatus.playing) {
      imageCache?.prefetch(value.game);
    }
    notifyListeners();
  }

  Future<void> favorite(Game game) =>
      save(_changed(game, {'favorite': !(entry(game)?.favorite ?? false)}));
  Future<void> setStatus(Game game, LibraryStatus? status) async {
    if (status == LibraryStatus.playing) {
      await startPlaying(game);
      return;
    }
    if (status == LibraryStatus.completed) {
      await completePlaythrough(game, completionDraft(game));
      return;
    }
    await save(_changed(game, {'status': status?.name}));
  }

  Future<void> startPlaying(Game game) async {
    final old = entry(game), current = active(game);
    if (old?.status == LibraryStatus.playing) return;
    final run = current != null && !current.completed
        ? current
        : GamePlaythrough(
            id: '${clock().microsecondsSinceEpoch}-${_ids++}',
            startDate: today,
          );
    await save(
      _changed(game, {
        'status': 'playing',
        'activePlaythroughId': run.id,
        'playthroughs': [
          ...old?.playthroughs
                  .where((r) => r.id != run.id)
                  .map((r) => r.toJson()) ??
              [],
          run.toJson(),
        ],
      }),
    );
  }

  GamePlaythrough completionDraft(Game game) {
    final current = active(game);
    return GamePlaythrough(
      id: current != null && !current.completed
          ? current.id
          : '${clock().microsecondsSinceEpoch}-${_ids++}',
      startDate: current != null && !current.completed
          ? current.startDate
          : null,
      endDate: today,
      completed: true,
    );
  }

  void validateDates(GamePlaythrough run) {
    if ((run.startDate != null &&
            calendarDate(run.startDate!).isAfter(today)) ||
        (run.endDate != null && calendarDate(run.endDate!).isAfter(today))) {
      throw ArgumentError('Dates cannot be in the future.');
    }
    if (run.startDate != null &&
        run.endDate != null &&
        inclusiveDays(run.startDate!, run.endDate!) < 1) {
      throw ArgumentError('End date must be on or after start date.');
    }
    if (!run.completed && run.endDate != null) {
      throw ArgumentError('An active run has no end date.');
    }
  }

  Future<void> completePlaythrough(
    Game game,
    GamePlaythrough run, {
    bool? favorite,
  }) async {
    validateDates(run);
    if (!run.completed) throw ArgumentError('Completion required');
    final old = entry(game);
    final existing = old?.playthroughs.where((r) => r.id == run.id).firstOrNull;
    if (existing?.completed == true) return;
    await save(
      _changed(game, {
        'status': 'completed',
        'favorite': favorite ?? old?.favorite ?? false,
        'completedRuns': (old?.completedRuns ?? 0) + 1,
        'activePlaythroughId': null,
        'playthroughs': [
          ...old?.playthroughs
                  .where((r) => r.id != run.id)
                  .map((r) => r.toJson()) ??
              [],
          run.toJson(),
        ],
      }),
    );
  }

  Future<void> updateDates(Game game, GamePlaythrough run) async {
    validateDates(run);
    final old = entry(game);
    if (old == null) throw StateError('Save the game first.');
    final exists = old.playthroughs.any((r) => r.id == run.id);
    final prior = old.playthroughs.where((r) => r.id == run.id).firstOrNull;
    if (prior != null && prior.completed != run.completed) {
      throw ArgumentError('Edit dates without changing completion state.');
    }
    await save(
      _changed(game, {
        'playthroughs': [
          for (final r in old.playthroughs)
            if (r.id == run.id) run.toJson() else r.toJson(),
          if (!exists) run.toJson(),
        ],
        if (!run.completed) 'activePlaythroughId': run.id,
      }),
    );
  }

  Future<void> updateLibrary(
    Game game, {
    required LibraryStatus? status,
    required bool favorite,
  }) async {
    await setStatus(game, status);
    await save(
      _changed(game, {
        'favorite': favorite,
        if (status == LibraryStatus.wantToPlay) 'bookmarked': true,
      }),
    );
  }

  Future<void> toggleSaved(Game game) async {
    final old = entry(game), saved = !(entry(game)?.bookmarked ?? false);
    await save(
      _changed(game, {
        'bookmarked': saved,
        'status': old?.status == LibraryStatus.wantToPlay && !saved
            ? null
            : old?.status?.name ?? (saved ? 'wantToPlay' : null),
      }),
    );
  }

  Future<void> remove(Game game) async {
    await storage.library.delete(game.key);
    notifyListeners();
  }
}
