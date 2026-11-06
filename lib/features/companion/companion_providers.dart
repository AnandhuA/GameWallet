import '../../core/catalog_identity.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/companion_models.dart';
import '../../core/companion_repository.dart';
import '../../core/game_repository.dart';
import '../../core/models.dart';
import '../library/library_provider.dart';

class JournalProvider extends ChangeNotifier {
  final CompanionRepository repository;
  final CatalogIdentity? identities;
  JournalProvider(this.repository, {this.identities}) {
    identities?.addListener(notifyListeners);
  }
  @override
  void dispose() {
    identities?.removeListener(notifyListeners);
    super.dispose();
  }

  List<PlaythroughEntry> entries(bool demo, {String? gameKey}) =>
      repository
          .records('journal')
          .map(PlaythroughEntry.fromJson)
          .where(
            (e) =>
                e.game.demo == demo &&
                (gameKey == null ||
                    (identities?.keys(gameKey) ?? {gameKey}).contains(
                      e.game.key,
                    )),
          )
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  PlaythroughEntry? latest(Game game) =>
      entries(game.demo, gameKey: game.key).firstOrNull;
  Future<void> save(PlaythroughEntry entry) async {
    if (entry.rating != null &&
        (entry.rating! < .5 ||
            entry.rating! > 5 ||
            entry.rating! * 2 != (entry.rating! * 2).round())) {
      throw ArgumentError('Use half-star ratings from 0.5 to 5.');
    }
    if (!['yes', 'maybe', 'no'].contains(entry.recommendation)) {
      throw ArgumentError('Invalid recommendation');
    }
    await repository.put('journal', entry.id, entry.toJson());
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await repository.remove('journal', id);
    notifyListeners();
  }

  String newId() => repository.newId();
}

class LineUpProvider extends ChangeNotifier {
  final CompanionRepository repository;
  LineUpProvider(this.repository);
  bool loading = false;
  String? error;
  List<GameLineUp> entries(bool demo) => repository
      .records('lineup')
      .map(GameLineUp.fromJson)
      .where((l) => l.demo == demo)
      .toList();
  GameLineUp? byId(String id) => repository
      .records('lineup')
      .map(GameLineUp.fromJson)
      .where((l) => l.id == id)
      .firstOrNull;
  Future<void> save(GameLineUp list) async {
    if (list.title.trim().isEmpty) {
      throw ArgumentError('Add a LineUp name.');
    }
    if (list.games.any((g) => g.demo != list.demo)) {
      throw ArgumentError('Demo and real games cannot be mixed.');
    }
    final unique = {for (final g in list.games) g.key: g};
    final cover = unique.containsKey(list.coverKey)
        ? list.coverKey
        : unique.keys.firstOrNull;
    final normalized = GameLineUp(
      id: list.id,
      title: list.title.trim(),
      description: list.description,
      games: unique.values.toList(),
      color: list.color,
      coverKey: cover,
      favorite: list.favorite,
      starter: list.starter,
      demo: list.demo,
    );
    await repository.put('lineup', list.id, normalized.toJson());
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await repository.remove('lineup', id);
    notifyListeners();
  }

  Future<GameLineUp> clone(GameLineUp original) async {
    final copy = original.copy(
      id: repository.newId(),
      title: '${original.title} copy',
      starter: false,
      favorite: false,
    );
    await save(copy);
    return copy;
  }

  int completed(GameLineUp list, LibraryProvider library) => list.games
      .where((g) => library.entry(g)?.status == LibraryStatus.completed)
      .length;
  Future<void> loadStarters(GameRepository catalog, bool demo) async {
    if (loading) {
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    final failures = <String>[];
    try {
      final filters = await catalog.filters(demo);
      for (final genre in ['Adventure', 'Strategy', 'Racing']) {
        final id = 'starter:${demo ? 'demo' : 'rawg'}:$genre';
        if (byId(id) != null) {
          continue;
        }
        try {
          final genreId = filters.genres.entries
              .where((e) => e.value.toLowerCase() == genre.toLowerCase())
              .firstOrNull
              ?.key;
          if (genreId == null) {
            throw StateError('Genre unavailable');
          }
          final results = await catalog.games(
            demo: demo,
            genre: genreId,
            sort: 'rating',
          );
          final verified = <Game>[];
          for (final candidate in results.games.take(3)) {
            final game = (await catalog.detail(candidate.id, demo)).$1;
            if (game.key != candidate.key || game.title.isEmpty) {
              throw StateError('Record could not be verified');
            }
            verified.add(game);
          }
          if (verified.length < 2) {
            throw StateError('Not enough verified games');
          }
          verified.sort(
            (a, b) => (a.release ?? DateTime(9999)).compareTo(
              b.release ?? DateTime(9999),
            ),
          );
          await save(
            GameLineUp(
              id: id,
              title: '$genre starters',
              description:
                  'A curated sampler of $genre games. Not an official RAWG collection.',
              games: verified,
              starter: true,
              demo: demo,
            ),
          );
        } catch (_) {
          failures.add(genre);
        }
      }
      if (failures.isNotEmpty) {
        error =
            'Could not load ${failures.join(', ')} starters. Existing lists are preserved. Check your connection and retry.';
      }
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }
}

class CalendarProvider extends ChangeNotifier {
  final CompanionRepository repository;
  CalendarProvider(this.repository);
  List<PlaySessionPlan> entries(bool demo) =>
      repository
          .records('plan')
          .map(PlaySessionPlan.fromJson)
          .where((p) => p.game.demo == demo)
          .toList()
        ..sort((a, b) => a.scheduled.compareTo(b.scheduled));
  Future<void> save(PlaySessionPlan plan) async {
    await repository.put('plan', plan.id, plan.toJson());
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await repository.remove('plan', id);
    notifyListeners();
  }
}

class DiscoveryPreferencesProvider extends ChangeNotifier {
  final CompanionRepository repository;
  final CatalogIdentity? identities;
  DiscoveryPreferencesProvider(this.repository, {this.identities}) {
    identities?.addListener(notifyListeners);
  }
  @override
  void dispose() {
    identities?.removeListener(notifyListeners);
    super.dispose();
  }

  bool hidden(Game game) => (identities?.keys(game.key) ?? {game.key}).any(
    (key) => repository.box.get('hidden:$key') != null,
  );
  List<Game> hiddenGames(bool demo) => repository
      .records('hidden')
      .map(Game.fromJson)
      .where((g) => g.demo == demo)
      .toList();
  Future<void> setHidden(Game game, bool value) async {
    if (value) {
      await repository.put('hidden', game.key, game.toJson());
    } else {
      await repository.remove('hidden', game.key);
    }
    notifyListeners();
  }
}

class WheelProvider extends ChangeNotifier {
  List<Game> candidates = [], frozen = [];
  Game? winner;
  bool spinning = false;
  int selectedIndex = 0;
  double targetAngle = 0;
  final Random random;
  WheelProvider({Random? random}) : random = random ?? Random();
  void replace(List<Game> games) {
    if (spinning) {
      return;
    }
    candidates = {for (final g in games) g.key: g}.values.take(12).toList();
    winner = null;
    notifyListeners();
  }

  void remove(Game game) {
    if (!spinning) {
      candidates.removeWhere((g) => g.key == game.key);
      winner = null;
      notifyListeners();
    }
  }

  bool begin() {
    if (spinning || candidates.isEmpty) {
      return false;
    }
    frozen = List.unmodifiable(candidates);
    selectedIndex = random.nextInt(frozen.length);
    spinning = true;
    winner = null;
    final segment = 2 * pi / frozen.length;
    final desired = (2 * pi - (selectedIndex + .5) * segment) % (2 * pi);
    targetAngle += 8 * pi + ((desired - targetAngle % (2 * pi)) % (2 * pi));
    notifyListeners();
    return true;
  }

  void finish() {
    if (spinning) {
      winner = frozen[selectedIndex];
      spinning = false;
      notifyListeners();
    }
  }
}

List<Game> smartCandidates(
  Iterable<Game> source,
  LibraryProvider library,
  DiscoveryPreferencesProvider hidden, {
  String? platform,
  String? genre,
  String mood = 'Any',
  bool unfinished = true,
  List<String> preferredGenres = const [],
}) {
  const moods = {
    'Relaxed': ['Casual', 'Puzzle', 'Simulation'],
    'Challenge': ['Action', 'Platformer', 'Fighting'],
    'Story': ['Adventure', 'RPG', 'Role-playing'],
    'Strategic': ['Strategy', 'Board Games', 'Card'],
  };
  final candidates =
      {for (final g in source) library.identities?.canonical(g.key) ?? g.key: g}
          .values
          .where(
            (g) =>
                !hidden.hidden(g) &&
                (platform == null || g.platforms.contains(platform)) &&
                (genre == null || g.genres.contains(genre)) &&
                (mood == 'Any' ||
                    g.genres.any((v) => (moods[mood] ?? []).contains(v))) &&
                (!unfinished ||
                    ![
                      LibraryStatus.completed,
                      LibraryStatus.dropped,
                    ].contains(library.entry(g)?.status)),
          )
          .toList();
  int score(Game g) => g.genres.where(preferredGenres.contains).length;
  final order = {
    for (var i = 0; i < candidates.length; i++) candidates[i].key: i,
  };
  candidates.sort((a, b) {
    final rank = score(b).compareTo(score(a));
    return rank != 0 ? rank : order[a.key]!.compareTo(order[b.key]!);
  });
  return candidates;
}
