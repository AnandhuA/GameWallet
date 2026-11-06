import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/game_repository.dart';
import '../../core/models.dart';

class GameDetailsProvider extends ChangeNotifier {
  final GameRepository repository;
  Game game;
  bool loading = false, stale = false;
  String? error;
  List<Game> similar = [];
  List<Game> catalogMatches = [];
  Future<void> confirmCatalogMatch(Game candidate) async {
    await repository.confirmMatch(game, candidate);
    await load();
  }

  final CancelToken _cancel = CancelToken();
  GameDetailsProvider(this.repository, this.game);
  Future<void> load({bool forceRefresh = false}) async {
    if (!game.demo && !['rawg', 'freetogame'].contains(game.source)) {
      error =
          'Saved IGDB entry. Your notes and library are preserved. Search RAWG to save its current listing; IDs from different catalogs are separate.';
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.detailGame(
        game,
        cancel: _cancel,
        forceRefresh: forceRefresh,
      );
      if (_cancel.isCancelled) {
        return;
      }
      game = result.$1;
      stale = result.$2;
      try {
        catalogMatches = await repository.otherMatches(game, cancel: _cancel);
      } catch (_) {
        catalogMatches = [];
      }
      if (_cancel.isCancelled) return;
      final values = await Future.wait(
        game.similar.take(6).map((id) async {
          try {
            return (await repository.detail(id, game.demo, cancel: _cancel)).$1;
          } catch (_) {
            return null;
          }
        }),
      );
      if (_cancel.isCancelled) {
        return;
      }
      similar = values.whereType<Game>().toList();
    } catch (e) {
      if (!_cancel.isCancelled) {
        error = e.toString();
      }
    }
    if (!_cancel.isCancelled) {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cancel.cancel();
    super.dispose();
  }
}
