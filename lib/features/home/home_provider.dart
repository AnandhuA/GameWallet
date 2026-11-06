import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/game_repository.dart';
import '../../core/models.dart';

class HomeProvider extends ChangeNotifier {
  final GameRepository repository;
  bool loading = false, stale = false;
  String? error, notice;
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
    notice = null;
    sections = {};
    stale = false;
    notifyListeners();
    try {
      final results = await Future.wait(
        ['popular', 'recent', 'upcoming', 'top', if (!demo) 'freetoplay'].map(
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
        for (var i = 0; i < results.length; i++)
          [
            'Popular right now',
            'Fresh releases',
            'On the horizon',
            'Top rated',
            'Free-to-play',
          ][i]: results[i].games,
      };
      if (sections.containsKey('Free-to-play')) {
        final primary = sections.entries
            .where((e) => e.key != 'Free-to-play')
            .expand((e) => e.value)
            .toList();
        final keys = primary.map(repository.canonicalKey).toSet();
        sections['Free-to-play'] = repository
            .deduplicate([...primary, ...sections['Free-to-play']!])
            .where((g) => !keys.contains(repository.canonicalKey(g)))
            .toList();
      }
      stale = results.any((r) => r.stale);
      notice = results
          .map((r) => r.notice)
          .whereType<String>()
          .toSet()
          .join(' ');
      if (notice!.isEmpty) notice = null;
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
