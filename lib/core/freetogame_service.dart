import 'dart:async';
import 'package:dio/dio.dart';
import 'models.dart';
import 'storage.dart';

class FreeToGameService {
  final Dio dio;
  Future<void> _gate = Future.value();
  DateTime? _lastStart;
  FreeToGameService({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://www.freetogame.com/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ),
          );
  Future<dynamic> get(
    String path,
    Map<String, dynamic> query,
    CancelToken cancel,
  ) async {
    final previous = _gate;
    final release = Completer<void>();
    _gate = release.future;
    try {
      await previous;
      final elapsed = _lastStart == null
          ? 125
          : DateTime.now().difference(_lastStart!).inMilliseconds;
      if (elapsed < 125) {
        await Future.any([
          Future<void>.delayed(Duration(milliseconds: 125 - elapsed)),
          cancel.whenCancel.then<void>((e) => throw e),
        ]);
      }
      if (cancel.isCancelled) throw cancel.cancelError!;
      _lastStart = DateTime.now();
    } finally {
      release.complete();
    }
    return (await dio.get<dynamic>(
      path,
      queryParameters: query,
      cancelToken: cancel,
    )).data;
  }

  void dispose() => dio.close(force: true);
}

String? _url(dynamic value) {
  if (value is! String) return null;
  final uri = Uri.tryParse(value);
  return uri != null &&
          ['https', 'http'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? value
      : null;
}

Game normalizeFreeToGame(dynamic value) {
  if (value is! Map ||
      value['id'] is! int ||
      (value['id'] as int) <= 0 ||
      value['title'] is! String ||
      (value['title'] as String).trim().isEmpty) {
    throw const FormatException('Invalid FreeToGame game');
  }
  final j = Map<String, dynamic>.from(value);
  String text(String key) => j[key] is String ? j[key] as String : '';
  final genre = switch (text('genre').toLowerCase()) {
    'arpg' || 'action rpg' || 'mmorpg' => 'RPG',
    'moba' => 'Strategy',
    'battle royale' => 'Shooter',
    _ => text('genre'),
  };
  final platform = text('platform').toLowerCase();
  return Game(
    id: j['id'] as int,
    source: 'freetogame',
    title: text('title').trim(),
    summary: text('description').isNotEmpty
        ? text('description')
        : text('short_description'),
    cover: _url(j['thumbnail']),
    release: DateTime.tryParse(text('release_date')),
    genres: genre.isEmpty ? [] : [genre],
    platforms: [
      if (platform.contains('windows') || platform.contains('pc')) 'PC',
      if (platform.contains('browser')) 'Web browser',
    ],
    developers: text('developer').isEmpty ? [] : [text('developer')],
    publishers: text('publisher').isEmpty ? [] : [text('publisher')],
    links: [if (_url(j['game_url']) case final String url) url],
    screenshots: [
      if (j['screenshots'] is List)
        for (final shot in j['screenshots'] as List)
          if (shot is Map)
            if (_url(shot['image']) case final String url) url,
    ],
    provenance: {'summary': 'freetogame', 'cover': 'freetogame'},
  );
}

class FreeToGameRepository {
  final AppStorage storage;
  final FreeToGameService service;
  FreeToGameRepository(this.storage, this.service);
  final Map<String, Future<(List<Game>, bool)>> _pending = {};
  final Map<String, CancelToken> _tokens = {};
  final Map<String, int> _readers = {};
  int _active = 0;
  final List<Completer<void>> _waiting = [];
  bool _disposed = false;
  Future<(List<Game>, bool)> _fetch(
    String path,
    Map<String, dynamic> query,
    CancelToken token,
    bool refresh,
    int generation,
  ) async {
    final key = 'freetogame:v1:$path:${query['id'] ?? 'all'}';
    List<Game> parse(dynamic data) {
      final list = path == '/games' ? data : [data];
      if (list is! List) {
        throw const FormatException('Invalid FreeToGame response');
      }
      final games = list.map(normalizeFreeToGame).toList();
      if (path != '/games' &&
          (games.length != 1 || games.single.id != query['id'])) {
        throw const FormatException('Unexpected FreeToGame detail identity');
      }
      return games;
    }

    final cached = storage.cached(key);
    List<Game>? old;
    try {
      if (cached != null) old = parse(cached['data']);
    } catch (_) {
      /* Recover malformed cache. */
    }
    if (!refresh &&
        old != null &&
        cached!['time'] is int &&
        !storage.expired(cached)) {
      return (old, false);
    }
    if (_active >= 2) {
      final slot = Completer<void>();
      _waiting.add(slot);
      await slot.future;
    } else {
      _active++;
    }
    try {
      if (token.isCancelled) throw token.cancelError!;
      final data = await service.get(path, query, token);
      final games = parse(data);
      if (token.isCancelled) throw token.cancelError!;
      if (generation == storage.cacheGeneration && !_disposed) {
        try {
          await storage.remember(key, data);
        } catch (_) {
          /* Live results still usable. */
        }
      }
      return (games, false);
    } catch (_) {
      if (token.isCancelled) rethrow;
      if (old != null) return (old, true);
      rethrow;
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _active--;
      }
    }
  }

  Future<(List<Game>, bool)> read(
    String path,
    CancelToken? cancel, {
    int? id,
    bool refresh = false,
  }) async {
    if (_disposed) throw StateError('Catalog closed');
    final reader = cancel ?? CancelToken();
    if (reader.isCancelled) throw reader.cancelError!;
    final generation = storage.cacheGeneration;
    final key = '$generation:$path:$id:$refresh';
    final future = _pending.putIfAbsent(key, () {
      final token = _tokens[key] = CancelToken();
      return _fetch(path, {'id': ?id}, token, refresh, generation).whenComplete(
        () {
          _pending.remove(key);
          _tokens.remove(key);
        },
      );
    });
    _readers[key] = (_readers[key] ?? 0) + 1;
    try {
      return await Future.any([
        future,
        reader.whenCancel.then<(List<Game>, bool)>((e) => throw e),
      ]);
    } finally {
      final count = (_readers[key] ?? 1) - 1;
      if (count == 0) {
        _readers.remove(key);
        _tokens[key]?.cancel('No catalog readers');
      } else {
        _readers[key] = count;
      }
    }
  }

  void dispose() {
    _disposed = true;
    for (final token in _tokens.values) {
      token.cancel('Catalog closed');
    }
    service.dispose();
  }
}
