import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/models.dart';
import 'price_models.dart';
import 'pricing_repository.dart';

class PricingProvider extends ChangeNotifier {
  final PricingRepository repository;
  final Game game;
  bool loading = false, opened = false, choosing = false;
  String? error;
  List<PriceMatch> matches = [];
  PriceListing? listing;
  PriceMatch? selected;
  CancelToken? _cancel;
  Timer? _expiry;
  int _generation = 0;
  bool _disposed = false;
  PricingProvider(this.repository, this.game);

  bool get outdated =>
      listing != null &&
      (listing!.stale ||
          repository.storage.clock().difference(listing!.checkedAt) >=
              const Duration(hours: 1));

  Future<void> open() async {
    if (opened) return;
    opened = true;
    await load();
  }

  Future<void> load({bool refresh = false, bool choose = false}) async {
    if (_disposed || loading) return;
    _cancel?.cancel('Superseded');
    final token = _cancel = CancelToken();
    final generation = ++_generation;
    final cacheGeneration = repository.storage.cacheGeneration;
    loading = true;
    error = null;
    choosing = choose;
    notifyListeners();
    bool current() =>
        !_disposed && generation == _generation && !token.isCancelled;
    try {
      var match = choose
          ? null
          : selected ?? repository.mapping(game.key, game.title);
      if (match == null) {
        final candidates = await repository.search(
          game.title,
          token,
          refresh: refresh,
          cacheGeneration: cacheGeneration,
        );
        if (!current()) return;
        matches = candidates;
        match = choose ? null : exactPriceMatch(game.title, candidates);
      }
      if (match == null) {
        choosing = true;
        listing = null;
        selected = null;
        _expiry?.cancel();
      } else {
        final result = await repository.listing(
          match,
          token,
          refresh: refresh,
          cacheGeneration: cacheGeneration,
        );
        if (!current()) return;
        await repository.confirm(game.key, game.title, match, cacheGeneration);
        if (!current()) return;
        selected = match;
        listing = result;
        choosing = false;
        _expiry?.cancel();
        final remaining = result.checkedAt
            .add(const Duration(hours: 1))
            .difference(repository.storage.clock());
        if (remaining > Duration.zero) {
          _expiry = Timer(remaining, () {
            if (!_disposed) notifyListeners();
          });
        }
      }
    } catch (e) {
      if (current()) {
        error = e is PricingFailure
            ? e.message
            : 'Could not load store prices. Please try again.';
      }
    } finally {
      if (current()) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(PriceMatch match) async {
    if (loading || _disposed) return;
    selected = match;
    listing = null;
    choosing = false;
    await load();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _cancel?.cancel('Price section closed');
    _expiry?.cancel();
    super.dispose();
  }
}
