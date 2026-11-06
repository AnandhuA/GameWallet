import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_service.dart';
import 'demo.dart';
import 'models.dart';
import 'storage.dart';

class GameRepository {
  bool get hasSupplementalCatalog => false;
  final AppStorage storage;
  final ApiService api;
  GameRepository(this.storage, this.api);
  Future<(dynamic, bool)> _read(
    String path,
    Map<String, dynamic> query,
    CancelToken? cancel, {
    bool forceRefresh = false,
  }) async {
    final key = 'rawg:v2:$path:${jsonEncode(query)}';
    final generation = storage.cacheGeneration;
    var cached = storage.cached(key);
    bool valid(dynamic data) {
      try {
        if (path == '/games') {
          for (final j in data['games'] as List) {
            Game.fromJson(Map<String, dynamic>.from(j));
          }
        } else if (path.startsWith('/games/')) {
          Game.fromJson(Map<String, dynamic>.from(data['game']));
        } else {
          for (final items in [data['genres'], data['platforms']]) {
            for (final item in items as List) {
              if (item['id'] == null || item['name'] is! String) return false;
            }
          }
        }
        return true;
      } catch (_) {
        return false;
      }
    }

    if (cached != null && (cached['time'] is! int || !valid(cached['data']))) {
      await storage.cache.delete(key);
      cached = null;
    }
    if (!forceRefresh && cached != null && !storage.expired(cached)) {
      return (cached['data'], false);
    }
    try {
      final data = await api.get(path, query, cancel: cancel);
      if (path == '/games' && data['games'] is! List ||
          path.startsWith('/games/') && data['game'] is! Map ||
          path == '/filters' &&
              (data['genres'] is! List || data['platforms'] is! List)) {
        throw const ApiFailure('The server returned invalid catalog data.');
      }
      if (!valid(data)) throw const ApiFailure('Invalid catalog data.');
      if (generation == storage.cacheGeneration) {
        await storage.remember(key, data);
      }
      return (data, false);
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        rethrow;
      }
      if (cached != null) {
        return (cached['data'], true);
      }
      rethrow;
    }
  }

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
    query = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (demo) {
      var list = demoGames
          .where(
            (g) =>
                g.title.toLowerCase().contains(query.toLowerCase()) &&
                (genre == null || g.genres.contains(genre)) &&
                (platform == null ||
                    platform.split(',').any(g.platforms.contains)) &&
                (year == null || g.release?.year == year),
          )
          .toList();
      final now = DateTime.now();
      if (feed == 'recent') {
        list = list.where((g) => g.release!.isBefore(now)).toList();
      }
      if (feed == 'upcoming') {
        list = list.where((g) => g.release!.isAfter(now)).toList();
      }
      if (sort == 'rating') {
        list.sort((a, b) => (b.rating ?? -1).compareTo(a.rating ?? -1));
      }
      if (sort == 'release' || feed == 'recent') {
        list.sort((a, b) => b.release!.compareTo(a.release!));
      }
      if (feed == 'upcoming') {
        list.sort((a, b) => a.release!.compareTo(b.release!));
      }
      return CatalogResult(
        list.skip(page * 20).take(20).toList(),
        hasMore: list.length > (page + 1) * 20,
      );
    }
    final (data, stale) = await _read(
      '/games',
      {
        'feed': feed,
        'q': query,
        'sort': sort,
        if (precise) 'precise': true,
        'page': page,
        'genre': ?genre,
        'platform': ?platform,
        'year': ?year,
      },
      cancel,
      forceRefresh: forceRefresh,
    );
    try {
      return CatalogResult(
        (data['games'] as List)
            .map((j) => Game.fromJson(Map<String, dynamic>.from(j)))
            .toList(),
        hasMore: data['hasMore'] == true,
        stale: stale,
      );
    } catch (_) {
      throw const ApiFailure('The server returned invalid game data.');
    }
  }

  Future<(Game, bool)> detail(
    int id,
    bool demo, {
    CancelToken? cancel,
    bool forceRefresh = false,
  }) async {
    if (demo) {
      return (demoGames.firstWhere((g) => g.id == id), false);
    }
    final (data, stale) = await _read(
      '/games/$id',
      {},
      cancel,
      forceRefresh: forceRefresh,
    );
    try {
      return (Game.fromJson(Map<String, dynamic>.from(data['game'])), stale);
    } catch (_) {
      throw const ApiFailure('This game could not be loaded.');
    }
  }

  List<Game> deduplicate(Iterable<Game> games) =>
      {for (final game in games) game.key: game}.values.toList();
  String canonicalKey(Game game) => game.key;
  Future<(Game, bool)> detailGame(
    Game game, {
    CancelToken? cancel,
    bool forceRefresh = false,
  }) => detail(game.id, game.demo, cancel: cancel, forceRefresh: forceRefresh);
  Future<List<Game>> otherMatches(Game game, {CancelToken? cancel}) async => [];
  Future<void> confirmMatch(Game game, Game candidate) async =>
      throw UnsupportedError('No supplementary catalog');

  Future<CatalogFilters> filters(bool demo, {bool forceRefresh = false}) async {
    if (demo) {
      return CatalogFilters(
        {for (final g in demoGames.expand((g) => g.genres).toSet()) g: g},
        {for (final p in demoGames.expand((g) => g.platforms).toSet()) p: p},
      );
    }
    final (data, _) = await _read(
      '/filters',
      {},
      null,
      forceRefresh: forceRefresh,
    );
    Map<String, String> parse(dynamic items) => {
      for (final item in items as List) '${item['id']}': item['name'] as String,
    };
    return CatalogFilters(parse(data['genres']), parse(data['platforms']));
  }
}
