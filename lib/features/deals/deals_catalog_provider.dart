import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/game_repository.dart';
import '../../core/models.dart';
import 'deal_record.dart';

String dealTitleKey(String title) => title
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

Game? exactDealMatch(DealRecord record, CatalogResult result) {
  final exact = result.games
      .where(
        (g) =>
            !g.demo &&
            ['rawg', 'freetogame'].contains(g.source) &&
            dealTitleKey(g.title) == dealTitleKey(record.title) &&
            (record.platform == 'unknown' ||
                g.platforms.any(
                  (p) =>
                      p.toLowerCase() ==
                      switch (record.platform) {
                        'pc' => 'pc',
                        'android' => 'android',
                        'ios' => 'ios',
                        _ => '',
                      },
                )),
      )
      .toList();
  return exact.length == 1 && !result.hasMore ? exact.single : null;
}

/// Shares visible-row lookups; the existing repository owns persistent caching.
class DealsCatalogProvider extends ChangeNotifier {
  final GameRepository repository;
  bool get supportsKeyless => repository.hasSupplementalCatalog;
  DealsCatalogProvider(this.repository)
    : _generation = repository.storage.cacheGeneration;
  int _generation;
  final Map<String, CatalogResult> results = {};
  final Map<String, DateTime> _times = {};
  final Map<String, Future<CatalogResult>> _pending = {};
  final List<Completer<void>> _waiting = [];
  final CancelToken _cancel = CancelToken();
  int _active = 0;
  bool _disposed = false;
  String lookupKey(DealRecord record) =>
      'precise-v1:${dealTitleKey(record.title)}:${record.platform}';
  Game? coverGame(DealRecord record) {
    if (_generation != repository.storage.cacheGeneration) return null;
    final result = results[lookupKey(record)];
    return result == null ? null : exactDealMatch(record, result);
  }

  Future<CatalogResult> lookup(DealRecord record, {bool refresh = false}) {
    if (_disposed) return Future.error(StateError('Catalog closed'));
    if (_generation != repository.storage.cacheGeneration) {
      results.clear();
      _times.clear();
      _generation = repository.storage.cacheGeneration;
    }
    final recordKey = lookupKey(record);
    final key = '$_generation:$recordKey';
    if (!refresh &&
        results.containsKey(recordKey) &&
        _times[recordKey] != null &&
        repository.storage.clock().difference(_times[recordKey]!) <
            repository.storage.expiry) {
      return Future.value(results[recordKey]);
    }
    return _pending.putIfAbsent(
      key,
      () => _lookup(record, refresh).whenComplete(() {
        _pending.remove(key);
      }),
    );
  }

  Future<CatalogResult> _lookup(DealRecord record, bool refresh) async {
    final generation = repository.storage.cacheGeneration;
    if (_active >= 2) {
      final slot = Completer<void>();
      _waiting.add(slot);
      await slot.future;
    } else {
      _active++;
    }
    try {
      if (_cancel.isCancelled) throw _cancel.cancelError!;
      final result = await repository.games(
        demo: false,
        query: record.title,
        sort: 'relevance',
        precise: true,
        platform: switch (record.platform) {
          'pc' => '4',
          'android' => '21',
          'ios' => '3',
          _ => null,
        },
        cancel: _cancel,
        forceRefresh: refresh,
      );
      if (!_disposed && generation == repository.storage.cacheGeneration) {
        results[lookupKey(record)] = result;
        _times[lookupKey(record)] = repository.storage.clock();
        while (results.length > 200) {
          _times.remove(results.keys.first);
          results.remove(results.keys.first);
        }
        notifyListeners();
      }
      return result;
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel.cancel('Deals catalog closed');
    super.dispose();
  }
}

class DealDetailsProvider extends ChangeNotifier {
  final DealsCatalogProvider? catalog;
  final DealRecord record;
  DealDetailsProvider(this.catalog, this.record);
  bool loading = false, stale = false;
  String? error;
  Game? game;
  List<Game> candidates = [];
  CancelToken? _detail;
  bool _disposed = false;
  int _revision = 0;
  Future<void> load({bool refresh = false}) async {
    if (_disposed) return;
    final revision = ++_revision;
    _detail?.cancel('Refreshing match');
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (catalog == null) throw StateError('Catalog unavailable');
      final result = await catalog!.lookup(record, refresh: refresh);
      if (_disposed || revision != _revision) return;
      stale = result.stale;
      candidates = result.games
          .where((g) => !g.demo && ['rawg', 'freetogame'].contains(g.source))
          .toList();
      final exact = exactDealMatch(record, result);
      if (exact != null) await _select(exact, revision);
    } catch (_) {
      if (!_disposed && revision == _revision) {
        error =
            'Additional game information is unavailable. Add a RAWG key in Settings or retry when online.';
      }
    } finally {
      if (!_disposed && revision == _revision) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(Game selected) => _select(selected, ++_revision);
  Future<void> _select(Game selected, int revision) async {
    if (_disposed || catalog == null) return;
    _detail?.cancel('Changed game match');
    final cancel = _detail = CancelToken();
    game = selected;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await catalog!.repository.detailGame(
        selected,
        cancel: cancel,
      );
      if (!_disposed && !cancel.isCancelled && revision == _revision) {
        game = result.$1;
        stale = stale || result.$2;
      }
    } catch (_) {
      if (!_disposed && !cancel.isCancelled && revision == _revision) {
        error =
            'Full game information could not be loaded. The giveaway record is still available.';
      }
    } finally {
      if (!_disposed && !cancel.isCancelled && revision == _revision) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _detail?.cancel('Deal details closed');
    super.dispose();
  }
}
