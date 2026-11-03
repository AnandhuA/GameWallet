import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/game_repository.dart';
import '../../core/models.dart';

class HomeProvider extends ChangeNotifier {
  final GameRepository repository;
  bool loading = false, stale = false;
  String? error;
  Map<String, List<Game>> sections = {};
  CatalogFilters filters = const CatalogFilters({}, {});
  int _generation = 0;
  CancelToken? _cancel;
  HomeProvider(this.repository);
  Future<void> load(
    bool demo,
    List<String> platforms, {
    bool forceRefresh = false,
  }) async {
    _cancel?.cancel();
    final cancel = _cancel = CancelToken();
    final generation = ++_generation;
    loading = true;
    error = null;
    sections = {};
    stale = false;
    notifyListeners();
    try {
      final results = await Future.wait(
        ['popular', 'recent', 'upcoming', 'top'].map(
          (feed) => repository.games(
            demo: demo,
            cancel: cancel,
            forceRefresh: forceRefresh,
            feed: feed == 'top' ? 'search' : feed,
            sort: feed == 'top' ? 'rating' : 'popular',
            platform: platforms.isEmpty ? null : platforms.join(','),
          ),
        ),
      );
      final metadata = await repository.filters(
        demo,
        forceRefresh: forceRefresh,
      );
      if (generation != _generation) {
        return;
      }
      sections = {
        for (var i = 0; i < 4; i++)
          [
            'Popular right now',
            'Fresh releases',
            'On the horizon',
            'Top rated',
          ][i]: results[i].games,
      };
      stale = results.any((r) => r.stale);
      filters = metadata;
    } catch (e) {
      if (generation == _generation) {
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
    _cancel?.cancel();
    super.dispose();
  }
}
