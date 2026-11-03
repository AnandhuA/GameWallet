import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/game_repository.dart';
import '../../core/models.dart';

class SearchProvider extends ChangeNotifier {
  final GameRepository repository;
  SearchProvider(this.repository);
  bool demo = true, loading = false, hasMore = false, stale = false;
  String query = '', sort = 'popular';
  String? genre, platform, error;
  int? year;
  List<String> preferredPlatforms = [];
  static const myPlatforms = '@preferred';
  int _page = 0, _generation = 0;
  Timer? _debounce;
  CancelToken? _cancel;
  List<Game> games = [];
  CatalogFilters filters = const CatalogFilters({}, {});
  void configure(bool value, List<String> preferred) {
    demo = value;
    query = '';
    genre = null;
    preferredPlatforms = List.of(preferred);
    platform = preferred.isEmpty ? null : myPlatforms;
    year = null;
    sort = 'popular';
    filters = const CatalogFilters({}, {});
    unawaited(_metadata(value));
    unawaited(search());
  }

  Future<void> _metadata(bool source) async {
    try {
      final result = await repository.filters(source);
      if (source == demo) {
        filters = result;
        notifyListeners();
      }
    } catch (_) {
      /* Results still work when filter metadata is unavailable. */
    }
  }

  void setQuery(String value) {
    final wasSearching = query.trim().isNotEmpty;
    final isSearching = value.trim().isNotEmpty;
    if (isSearching && !wasSearching) sort = 'relevance';
    if (!isSearching && sort == 'relevance') sort = 'popular';
    query = value;
    _debounce?.cancel();
    _cancel?.cancel();
    _generation++;
    loading = true;
    error = null;
    games = [];
    hasMore = false;
    notifyListeners();
    _debounce = Timer(const Duration(milliseconds: 350), () => search());
  }

  void apply({
    String? genreValue,
    String? platformValue,
    int? yearValue,
    String? sortValue,
  }) {
    genre = genreValue;
    platform = platformValue;
    year = yearValue;
    sort = sortValue ?? sort;
    unawaited(search());
  }

  Future<void> search({bool more = false}) async {
    if (more && (loading || !hasMore)) {
      return;
    }
    _debounce?.cancel();
    _cancel?.cancel();
    _cancel = CancelToken();
    final generation = ++_generation;
    final page = more ? _page + 1 : 0;
    loading = true;
    error = null;
    if (!more) {
      games = [];
      stale = false;
    }
    notifyListeners();
    try {
      final result = await repository.games(
        demo: demo,
        query: query.trim().replaceAll(RegExp(r'\s+'), ' '),
        genre: genre,
        platform: platform == myPlatforms
            ? preferredPlatforms.join(',')
            : platform,
        year: year,
        sort: sort,
        page: page,
        cancel: _cancel,
      );
      if (generation != _generation) {
        return;
      }
      final merged = <int, Game>{
        for (final g in games) g.id: g,
        for (final g in result.games) g.id: g,
      };
      games = merged.values.toList();
      _page = page;
      hasMore = result.hasMore;
      stale = stale || result.stale;
    } catch (e) {
      if (generation == _generation &&
          !(e is DioException && CancelToken.isCancel(e))) {
        error = e.toString();
      }
    }
    if (generation == _generation) {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _cancel?.cancel();
    super.dispose();
  }
}
