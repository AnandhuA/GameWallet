import 'dart:async';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'models.dart';

class ImageCacheService extends ChangeNotifier {
  final Box<dynamic>? box;
  final Dio dio;
  final DateTime Function() clock;
  final int maxBytes, maxEntries;
  final Duration expiry;
  final Map<String, Map<String, dynamic>> _memory = {};
  final Map<String, Future<Uint8List>> _pending = {};
  final Map<String, CancelToken> _tokens = {};
  final List<Completer<void>> _waiting = [];
  int _active = 0, _generation = 0;
  bool _disposed = false;
  ImageCacheService(
    this.box, {
    Dio? dio,
    DateTime Function()? clock,
    this.maxBytes = 100 * 1024 * 1024,
    this.maxEntries = 500,
    this.expiry = const Duration(days: 30),
  }) : dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
             ),
           ),
       clock = clock ?? DateTime.now;
  Iterable<String> get keys => (box?.keys.cast<String>() ?? _memory.keys).where(
    (key) => !key.startsWith('@access:'),
  );
  Map<String, dynamic>? _read(String key) {
    final value = box?.get(key) ?? _memory[key];
    if (value is! Map ||
        value['bytes'] is! Uint8List ||
        value['time'] is! int ||
        value['access'] is! int) {
      return null;
    }
    final access = box?.get('@access:$key');
    return {
      ...Map<String, dynamic>.from(value),
      if (access is int) 'access': access,
    };
  }

  int get count => keys.length;
  int get bytes => keys.fold(
    0,
    (sum, key) => sum + ((_read(key)?['bytes'] as Uint8List?)?.length ?? 0),
  );
  Future<void> _put(String key, Map<String, dynamic> value) async {
    if (box != null) {
      await box!.put(key, value);
    } else {
      _memory[key] = value;
    }
  }

  Future<void> _delete(String key) async {
    if (box != null) {
      await box!.delete(key);
      await box!.delete('@access:$key');
    } else {
      _memory.remove(key);
    }
  }

  Uint8List? peek(String url) => _read(url)?['bytes'] as Uint8List?;
  bool fresh(String url) {
    final time = _read(url)?['time'] as int?;
    return time != null &&
        clock().difference(DateTime.fromMillisecondsSinceEpoch(time)) < expiry;
  }

  Future<void> _acquire() async {
    if (_active < 3) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    await waiter.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _active--;
    }
  }

  Future<Uint8List> load(String url) {
    if (_disposed) return Future.error(StateError('Image cache closed'));
    return _pending.putIfAbsent(url, () {
      final future = _load(url, _generation);
      unawaited(
        future.then<void>(
          (_) {
            if (identical(_pending[url], future)) _pending.remove(url);
          },
          onError: (Object e, StackTrace s) {
            if (identical(_pending[url], future)) _pending.remove(url);
          },
        ),
      );
      return future;
    });
  }

  Future<Uint8List> _load(String url, int generation) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw ArgumentError('HTTPS image required');
    }
    final cached = _read(url);
    final old = cached?['bytes'] as Uint8List?;
    if (old != null && fresh(url)) {
      if (box != null) {
        await box!.put('@access:$url', clock().millisecondsSinceEpoch);
      } else {
        _memory[url]!['access'] = clock().millisecondsSinceEpoch;
      }
      return old;
    }
    await _acquire();
    final cancel = CancelToken();
    try {
      if (_disposed || generation != _generation) {
        throw StateError('Image request cancelled');
      }
      _tokens[url] = cancel;
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancel,
        onReceiveProgress: (received, total) {
          if (received > 10 * 1024 * 1024) cancel.cancel('Image too large');
        },
      );
      final data = Uint8List.fromList(response.data ?? []);
      final codec = await ui.instantiateImageCodec(
        data,
        targetWidth: 1,
        targetHeight: 1,
      );
      codec.dispose();
      if (_disposed || generation != _generation) {
        throw StateError('Image request cancelled');
      }
      if (data.length <= maxBytes) {
        await _put(url, {
          'bytes': data,
          'time': clock().millisecondsSinceEpoch,
          'access': clock().millisecondsSinceEpoch,
        });
        var evicted = false;
        while (count > maxEntries || bytes > maxBytes) {
          evicted = true;
          final oldest = keys.reduce(
            (a, b) =>
                (_read(a)?['access'] as int? ?? 0) <=
                    (_read(b)?['access'] as int? ?? 0)
                ? a
                : b,
          );
          await _delete(oldest);
        }
        if (evicted && box != null) await box!.compact();
        if (!_disposed) notifyListeners();
      }
      return data;
    } catch (_) {
      if (old != null && !_disposed && generation == _generation) return old;
      rethrow;
    } finally {
      if (identical(_tokens[url], cancel)) _tokens.remove(url);
      _release();
    }
  }

  void prefetch(Game game) {
    if (game.demo || _disposed) return;
    for (final url in <String>{
      if (game.cover != null) game.cover!,
      if (game.artwork != null) game.artwork!,
    }) {
      unawaited(
        load(url).then<void>((_) {}, onError: (Object e, StackTrace s) {}),
      );
    }
  }

  Future<void> clear() async {
    _generation++;
    for (final token in _tokens.values) {
      token.cancel();
    }
    _pending.clear();
    if (box != null) {
      await box!.clear();
    } else {
      _memory.clear();
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    for (final token in _tokens.values) {
      token.cancel();
    }
    super.dispose();
  }
}
