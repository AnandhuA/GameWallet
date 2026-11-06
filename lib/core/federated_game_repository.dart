import 'dart:convert';
import 'package:dio/dio.dart';
import 'game_repository.dart';
import 'models.dart';
import 'catalog_identity.dart';
import 'freetogame_service.dart';

class _SourceResult<T> {
  final T? value;
  final Object? error;
  const _SourceResult(this.value, this.error);
}

Future<_SourceResult<T>> _capture<T>(Future<T> future) async {
  try {
    return _SourceResult(await future, null);
  } catch (e) {
    return _SourceResult(null, e);
  }
}

class _CatalogSession {
  final _SourceResult<(List<Game>, bool)> extra;
  final bool primaryFailed;
  const _CatalogSession(this.extra, this.primaryFailed);
}

class FederatedGameRepository extends GameRepository {
  @override
  bool get hasSupplementalCatalog => true;
  final FreeToGameRepository supplemental;
  final CatalogIdentity identities;
  FederatedGameRepository(
    super.storage,
    super.api,
    this.supplemental,
    this.identities,
  );
  final Map<String, Game> _known = {};
  final Map<String, _CatalogSession> _sessions = {};
  int _sessionGeneration = -1;
  final Map<String, String> _platformNames = {
    '4': 'PC',
    '@browser': 'Web browser',
  };
  static const genres = {
    '4': 'Action',
    '2': 'Shooter',
    '5': 'RPG',
    '10': 'Strategy',
    '1': 'Racing',
    '15': 'Sports',
    '6': 'Fighting',
    '14': 'Simulation',
    '7': 'Puzzle',
  };
  static const fallbackFilters = CatalogFilters(genres, {
    '4': 'PC',
    '@browser': 'Web browser',
  });
  @override
  String canonicalKey(Game game) => identities.canonical(game.key);
  @override
  List<Game> deduplicate(Iterable<Game> games) {
    final items = games.toList();
    final primaryTitles = items
        .where((g) => g.source == 'rawg')
        .map((g) => catalogTitle(g.title))
        .toSet();
    final result = <String, Game>{};
    for (final g in items) {
      if (g.source == 'freetogame' &&
          primaryTitles.contains(catalogTitle(g.title)) &&
          identities.keys(g.key).length == 1) {
        continue;
      }
      final key = canonicalKey(g), previous = result[key];
      if (previous == null || g.source == 'rawg') result[key] = g;
    }
    return result.values.toList();
  }

  Future<void> _learn(List<Game> primary, List<Game> extra) async {
    final byTitle = <String, List<Game>>{};
    for (final game in extra) {
      byTitle.putIfAbsent(catalogTitle(game.title), () => []).add(game);
    }
    for (final game in primary) {
      _known[game.key] = game;
      final candidates = byTitle[catalogTitle(game.title)] ?? <Game>[];
      if (candidates.length == 1 &&
          primary
                  .where(
                    (g) => catalogTitle(g.title) == catalogTitle(game.title),
                  )
                  .length ==
              1 &&
          confirmedCatalogMatch(game, candidates.single) &&
          !identities.keys(game.key).contains(candidates.single.key)) {
        await identities.link(
          game,
          candidates.single,
          preferredKey: _known.keys.firstWhere(
            (key) => key == game.key || key == candidates.single.key,
          ),
        );
      }
    }
    for (final game in extra) {
      _known[game.key] = game;
    }
    while (_known.length > 1000) {
      _known.remove(_known.keys.first);
    }
  }

  Game _enrich(Game game, List<Game> extra) {
    final match = extra
        .where((g) => identities.keys(game.key).contains(g.key))
        .firstOrNull;
    return match == null ? game : supplementGame(game, match);
  }

  List<Game> _filter(
    List<Game> values, {
    String query = '',
    String? genre,
    String? platform,
    int? year,
    String feed = 'search',
    String sort = 'popular',
  }) {
    final tokens = catalogTitle(
      query,
    ).split(' ').where((t) => t.isNotEmpty).toList();
    var list = values.where((g) {
      final platformIds = platform?.split(',') ?? [];
      final platforms =
          platformIds.isEmpty ||
          platformIds.any(
            (p) =>
                _platformNames[p]?.toLowerCase() == 'pc' &&
                    g.platforms.contains('PC') ||
                (_platformNames[p]?.toLowerCase().contains('web') ?? false) &&
                    g.platforms.contains('Web browser'),
          );
      final genreName = genres[genre];
      return platforms &&
          (genre == null ||
              genreName != null &&
                  g.genres.any(
                    (v) => catalogTitle(v) == catalogTitle(genreName),
                  )) &&
          (year == null || g.release?.year == year) &&
          tokens.every((t) => catalogTitle(g.title).contains(t));
    }).toList();
    if (feed == 'recent') {
      list = list
          .where(
            (g) =>
                g.release != null &&
                !g.release!.isAfter(storage.clock()) &&
                storage.clock().difference(g.release!).inDays <= 180,
          )
          .toList();
    }
    if (feed == 'upcoming') {
      list = list
          .where(
            (g) => g.release != null && g.release!.isAfter(storage.clock()),
          )
          .toList();
    }
    if (sort == 'rating') return []; // This source has no comparable ratings.
    if (sort == 'release' || feed == 'recent' || feed == 'upcoming') {
      list.sort(
        (a, b) => feed == 'upcoming'
            ? (a.release ?? DateTime(9999)).compareTo(
                b.release ?? DateTime(9999),
              )
            : (b.release ?? DateTime(1)).compareTo(a.release ?? DateTime(1)),
      );
    } else if (query.isNotEmpty) {
      final q = catalogTitle(query);
      int rank(Game g) => catalogTitle(g.title) == q
          ? 0
          : catalogTitle(g.title).startsWith(q)
          ? 1
          : 2;
      list.sort((a, b) => rank(a).compareTo(rank(b)));
    }
    return list;
  }

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
    if (demo) {
      return super.games(
        demo: demo,
        feed: feed,
        query: query,
        genre: genre,
        platform: platform,
        year: year,
        sort: sort,
        precise: precise,
        page: page,
        cancel: cancel,
        forceRefresh: forceRefresh,
      );
    }
    if (_sessionGeneration != storage.cacheGeneration) {
      _sessions.clear();
      _sessionGeneration = storage.cacheGeneration;
    }
    final sessionKey = jsonEncode([
      feed,
      query.trim(),
      genre,
      platform,
      year,
      sort,
      precise,
    ]);
    final session = page > 0 && !forceRefresh ? _sessions[sessionKey] : null;
    final extraFuture = session == null
        ? _capture(supplemental.read('/games', cancel, refresh: forceRefresh))
        : Future.value(session.extra);
    final platformIds = platform
        ?.split(',')
        .where((p) => p != '@browser')
        .join(',');
    final skipPrimary = feed == 'freetoplay' || platform == '@browser';
    final primary = session?.primaryFailed == true
        ? const _SourceResult<CatalogResult>(
            null,
            'RAWG unavailable for this search session',
          )
        : await _capture(
            skipPrimary
                ? Future.value(const CatalogResult([]))
                : super.games(
                    demo: false,
                    feed: feed,
                    query: query,
                    genre: genre,
                    platform: platformIds,
                    year: year,
                    sort: sort,
                    precise: precise,
                    page: page,
                    cancel: cancel,
                    forceRefresh: forceRefresh,
                  ),
          );
    final extra = await extraFuture;
    if (cancel?.isCancelled ?? false) throw cancel!.cancelError!;
    if (page == 0) {
      _sessions[sessionKey] = _CatalogSession(extra, primary.value == null);
      while (_sessions.length > 8) {
        _sessions.remove(_sessions.keys.first);
      }
    }
    if (primary.value == null && extra.value == null) {
      throw primary.error ?? extra.error!;
    }
    final allExtra = extra.value?.$1 ?? <Game>[];
    final p = primary.value?.games ?? <Game>[];
    await _learn(p, allExtra);
    final selectedExtra = precise && query.trim().isNotEmpty
        ? allExtra
              .where((g) => catalogTitle(g.title) == catalogTitle(query))
              .toList()
        : allExtra;
    final filtered = feed == 'popular'
        ? <Game>[]
        : _filter(
            selectedExtra,
            query: query,
            genre: genre,
            platform: platform,
            year: year,
            feed: feed,
            sort: sort,
          );
    // Provider-local popularity is not numerically comparable across catalogs.
    final merged = deduplicate([
      ...p.map((g) => _enrich(g, allExtra)),
      ...filtered.skip(page * 20).take(20),
    ]);
    if (query.trim().isNotEmpty && sort == 'relevance') {
      final q = catalogTitle(query);
      int rank(Game g) => catalogTitle(g.title) == q
          ? 0
          : catalogTitle(g.title).startsWith(q)
          ? 1
          : 2;
      merged.sort((a, b) => rank(a).compareTo(rank(b)));
    } else if (sort == 'release' || feed == 'recent' || feed == 'upcoming') {
      merged.sort(
        (a, b) => feed == 'upcoming'
            ? (a.release ?? DateTime(9999)).compareTo(
                b.release ?? DateTime(9999),
              )
            : (b.release ?? DateTime(1)).compareTo(a.release ?? DateTime(1)),
      );
    }
    final notices = <String>[
      if (primary.value == null)
        'RAWG unavailable. Showing available FreeToGame results; console and mobile coverage may be missing.',
      if (extra.value == null)
        skipPrimary
            ? 'FreeToGame unavailable for this selection. Retry when online; browser access may be restricted.'
            : 'FreeToGame unavailable; showing RAWG results. Browser access may be restricted.',
      if (!skipPrimary && filtered.isNotEmpty && sort == 'popular')
        'FreeToGame games follow RAWG results; provider popularity scores are not compared.',
    ];
    return CatalogResult(
      merged,
      hasMore:
          (primary.value?.hasMore ?? false) ||
          filtered.length > (page + 1) * 20,
      stale: (primary.value?.stale ?? false) || (extra.value?.$2 ?? false),
      notice: notices.isEmpty ? null : notices.join(' '),
    );
  }

  @override
  Future<CatalogFilters> filters(bool demo, {bool forceRefresh = false}) async {
    if (demo) return super.filters(true, forceRefresh: forceRefresh);
    try {
      final result = await super.filters(false, forceRefresh: forceRefresh);
      _platformNames.addAll(result.platforms);
      return CatalogFilters(result.genres, {
        ...result.platforms,
        '@browser': 'Web browser',
      });
    } catch (_) {
      return fallbackFilters;
    }
  }

  @override
  Future<(Game, bool)> detailGame(
    Game game, {
    CancelToken? cancel,
    bool forceRefresh = false,
  }) async {
    if (game.demo || !['rawg', 'freetogame'].contains(game.source)) {
      return super.detailGame(game, cancel: cancel, forceRefresh: forceRefresh);
    }
    final extraResult = await _capture(
      supplemental.read(
        game.source == 'freetogame' ? '/game' : '/games',
        cancel,
        id: game.source == 'freetogame' ? game.id : null,
        refresh: forceRefresh,
      ),
    );
    if (cancel?.isCancelled ?? false) throw cancel!.cancelError!;
    if (game.source == 'freetogame') {
      if (extraResult.value == null) return (game, true);
      final extra = extraResult.value!.$1.single;
      _known[extra.key] = extra;
      var primary = identities
          .keys(extra.key)
          .map((k) => _known[k] ?? storage.library.get(k)?.game)
          .whereType<Game>()
          .where((g) => g.source == 'rawg')
          .firstOrNull;
      if (primary == null) {
        try {
          final search = await super.games(
            demo: false,
            query: extra.title,
            sort: 'relevance',
            precise: true,
            cancel: cancel,
          );
          final exact = search.games
              .where((g) => catalogTitle(g.title) == catalogTitle(extra.title))
              .toList();
          if (!search.hasMore && exact.length == 1) {
            final candidate = (await super.detailGame(
              exact.single,
              cancel: cancel,
            )).$1;
            if (confirmedCatalogMatch(candidate, extra)) {
              await _learn([candidate], [extra]);
              primary = candidate;
            }
          }
        } catch (_) {
          /* Supplementary details remain usable on their own. */
        }
        if (cancel?.isCancelled ?? false) throw cancel!.cancelError!;
        if (primary == null) return (extra, extraResult.value!.$2);
      }
      final raw = await _capture(
        super.detailGame(primary, cancel: cancel, forceRefresh: forceRefresh),
      );
      final merged = supplementGame(raw.value?.$1 ?? primary, extra);
      return (
        Game.fromJson({
          ...merged.toJson(),
          'id': extra.id,
          'source': 'freetogame',
          'provenance': {
            ...merged.provenance,
            'primary': 'rawg',
            if (merged.rating != null) 'rating': 'rawg',
          },
        }),
        extraResult.value!.$2 || raw.value == null || (raw.value?.$2 ?? false),
      );
    }
    final raw = await _capture(
      super.detailGame(game, cancel: cancel, forceRefresh: forceRefresh),
    );
    if (cancel?.isCancelled ?? false) throw cancel!.cancelError!;
    var extra = extraResult.value?.$1 ?? <Game>[];
    await _learn([raw.value?.$1 ?? game], extra);
    final match = extra
        .where((g) => identities.keys(game.key).contains(g.key))
        .firstOrNull;
    var extraStale = extraResult.value?.$2 ?? false;
    if (match != null) {
      final full = await _capture(
        supplemental.read('/game', cancel, id: match.id, refresh: forceRefresh),
      );
      if (cancel?.isCancelled ?? false) throw cancel!.cancelError!;
      if (full.value != null) {
        extra = [
          full.value!.$1.single,
          ...extra.where((g) => g.key != match.key),
        ];
        extraStale = extraStale || full.value!.$2;
      }
    }
    if (raw.value == null &&
        !extra.any((g) => identities.keys(game.key).contains(g.key))) {
      throw raw.error!;
    }
    return (
      _enrich(raw.value?.$1 ?? game, extra),
      raw.value == null || (raw.value?.$2 ?? false) || extraStale,
    );
  }

  @override
  Future<List<Game>> otherMatches(Game game, {CancelToken? cancel}) async {
    if (game.demo) return [];
    if (game.source == 'rawg') {
      final values = (await supplemental.read('/games', cancel)).$1;
      return values
          .where(
            (g) =>
                catalogTitle(g.title) == catalogTitle(game.title) &&
                !identities.keys(game.key).contains(g.key),
          )
          .toList();
    }
    if (game.source == 'freetogame') {
      final values = await super.games(
        demo: false,
        query: game.title,
        sort: 'relevance',
        precise: true,
        cancel: cancel,
      );
      await _learn(values.games, [game]);
      return values.games
          .where(
            (g) =>
                catalogTitle(g.title) == catalogTitle(game.title) &&
                !identities.keys(game.key).contains(g.key),
          )
          .toList();
    }
    return [];
  }

  @override
  Future<void> confirmMatch(Game game, Game candidate) async {
    if (catalogTitle(game.title) != catalogTitle(candidate.title)) {
      throw ArgumentError('Different game titles');
    }
    _known[game.key] = game;
    _known[candidate.key] = candidate;
    await identities.link(game, candidate);
  }
}
