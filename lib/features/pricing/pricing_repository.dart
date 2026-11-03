import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../core/storage.dart';
import 'price_models.dart';
import 'pricing_service.dart';

class _Flight {
  final CancelToken cancel = CancelToken();
  late final Future<dynamic> result;
  int readers = 0;
}

class _CachedPriceData {
  final dynamic data;
  final DateTime time;
  final bool stale;
  const _CachedPriceData(this.data, this.time, this.stale);
}

class PricingRepository {
  final AppStorage storage;
  final PricingService service;
  final Map<String, _Flight> _pending = {};
  PricingRepository(this.storage, this.service);

  Future<dynamic> _request(
    String path,
    Map<String, dynamic> query,
    CancelToken cancel,
  ) async {
    if (cancel.isCancelled) throw cancel.cancelError!;
    final key = '$path:${jsonEncode(query)}';
    var flight = _pending[key];
    if (flight == null || flight.cancel.isCancelled) {
      flight = _Flight();
      final current = flight;
      _pending[key] = current;
      current.result = service.get(path, query, current.cancel).whenComplete(
        () {
          if (identical(_pending[key], current)) _pending.remove(key);
        },
      );
    }
    flight.readers++;
    try {
      return await Future.any([
        flight.result,
        cancel.whenCancel.then<dynamic>((error) => throw error),
      ]);
    } finally {
      flight.readers--;
      if (flight.readers == 0) flight.cancel.cancel('No active price requests');
    }
  }

  Future<_CachedPriceData> _read(
    String path,
    Map<String, dynamic> query,
    CancelToken cancel,
    bool Function(dynamic) valid, {
    bool refresh = false,
    int? cacheGeneration,
    Duration freshness = const Duration(hours: 1),
  }) async {
    final key = 'prices:cheapshark:v1:$path:${jsonEncode(query)}';
    final generation = cacheGeneration ?? storage.cacheGeneration;
    Map<String, dynamic>? cached;
    try {
      cached = storage.cached(key);
      if (cached != null &&
          (cached['time'] is! int || !valid(cached['data']))) {
        await storage.cache.delete(key);
        cached = null;
      }
    } catch (_) {
      await storage.cache.delete(key);
      cached = null;
    }
    final time = cached == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            cached['time'] as int,
            isUtc: true,
          );
    if (!refresh &&
        cached != null &&
        storage.clock().difference(time!) < freshness) {
      return _CachedPriceData(cached['data'], time, false);
    }
    try {
      final data = await _request(path, query, cancel);
      if (cancel.isCancelled) throw cancel.cancelError!;
      if (!valid(data)) {
        throw const PricingFailure(
          'The price service returned incomplete data. Please retry.',
        );
      }
      final checked = storage.clock();
      if (generation == storage.cacheGeneration) {
        await storage.remember(key, data);
      }
      return _CachedPriceData(data, checked, false);
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) rethrow;
      if (cached != null && time != null) {
        return _CachedPriceData(cached['data'], time, true);
      }
      rethrow;
    }
  }

  static List<PriceMatch> _matches(dynamic data) {
    if (data is! List) throw const FormatException('Invalid search');
    final unique = <String, PriceMatch>{};
    for (final value in data) {
      final match = PriceMatch.fromJson(
        Map<String, dynamic>.from(value as Map),
      );
      unique[match.id] = match;
    }
    return unique.values.toList();
  }

  Future<List<PriceMatch>> search(
    String title,
    CancelToken cancel, {
    bool refresh = false,
    int? cacheGeneration,
  }) async {
    final result = await _read(
      '/games',
      {'title': title, 'limit': 30},
      cancel,
      (data) {
        try {
          _matches(data);
          return true;
        } catch (_) {
          return false;
        }
      },
      refresh: refresh,
      cacheGeneration: cacheGeneration,
    );
    return _matches(result.data);
  }

  String _mappingKey(String gameKey, String title) =>
      'prices:match:v1:$gameKey:${normalizedPriceTitle(title)}';
  PriceMatch? mapping(String gameKey, String title) {
    try {
      final value = storage.cached(_mappingKey(gameKey, title));
      return value == null
          ? null
          : PriceMatch.fromJson(
              Map<String, dynamic>.from(value['data'] as Map),
            );
    } catch (_) {
      return null;
    }
  }

  Future<void> confirm(
    String gameKey,
    String title,
    PriceMatch match,
    int generation,
  ) async {
    if (generation == storage.cacheGeneration) {
      await storage.remember(_mappingKey(gameKey, title), match.toJson());
    }
  }

  static Map<String, String> _stores(dynamic data) {
    if (data is! List || data.isEmpty) {
      throw const FormatException('Invalid stores');
    }
    final result = <String, String>{};
    for (final value in data) {
      if (value is! Map ||
          value['storeID'] is! String ||
          value['storeName'] is! String) {
        throw const FormatException('Invalid store');
      }
      if (value['isActive'] != 0 && value['isActive'] != '0') {
        result[value['storeID'] as String] = value['storeName'] as String;
      }
    }
    return result;
  }

  static bool _validListing(dynamic data, PriceMatch match) {
    if (data is! Map || data['info'] is! Map || data['deals'] is! List) {
      return false;
    }
    final title = data['info']['title'];
    if (title is! String ||
        normalizedPriceTitle(title) != normalizedPriceTitle(match.title)) {
      return false;
    }
    return (data['deals'] as List).every(
      (d) =>
          d is Map &&
          d['storeID'] is String &&
          d['dealID'] is String &&
          (d['dealID'] as String).isNotEmpty &&
          StoreOffer.parseCents(d['price']) != null,
    );
  }

  Future<PriceListing> listing(
    PriceMatch match,
    CancelToken cancel, {
    bool refresh = false,
    int? cacheGeneration,
  }) async {
    final generation = cacheGeneration ?? storage.cacheGeneration;
    final results = await Future.wait<Object?>([
      _read(
        '/games',
        {'id': match.id},
        cancel,
        (data) => _validListing(data, match),
        refresh: refresh,
        cacheGeneration: generation,
      ),
      _read(
        '/stores',
        {},
        cancel,
        (data) {
          try {
            _stores(data);
            return true;
          } catch (_) {
            return false;
          }
        },
        refresh: refresh,
        cacheGeneration: generation,
      ),
      rupeeRate(cancel, refresh: refresh, cacheGeneration: generation),
    ]);
    final prices = results[0] as _CachedPriceData;
    final shops = results[1] as _CachedPriceData;
    final stores = _stores(shops.data);
    final offers = <StoreOffer>[];
    final seen = <String>{};
    for (final row in prices.data['deals'] as List) {
      final store = row['storeID'] as String;
      if (!stores.containsKey(store) || !seen.add(row['dealID'] as String)) {
        continue;
      }
      final price = StoreOffer.parseCents(row['price'])!;
      offers.add(
        StoreOffer(
          storeId: store,
          storeName: stores[store]!,
          dealId: row['dealID'] as String,
          cents: price,
          retailCents: StoreOffer.parseCents(row['retailPrice']),
        ),
      );
    }
    offers.sort((a, b) {
      final price = a.cents.compareTo(b.cents);
      return price != 0 ? price : a.storeName.compareTo(b.storeName);
    });
    return PriceListing(
      match,
      List.unmodifiable(offers),
      prices.time,
      stale: prices.stale || shops.stale,
      rupeeRate: results[2] as RupeeRate?,
    );
  }

  Future<RupeeRate?> rupeeRate(
    CancelToken cancel, {
    bool refresh = false,
    int? cacheGeneration,
  }) async {
    try {
      final result = await _read(
        'https://api.frankfurter.dev/v2/rate/USD/INR',
        {},
        cancel,
        (data) {
          try {
            RupeeRate.fromJson(data);
            return true;
          } catch (_) {
            return false;
          }
        },
        refresh: refresh,
        cacheGeneration: cacheGeneration,
        freshness: const Duration(hours: 24),
      );
      return RupeeRate.fromJson(result.data, stale: result.stale);
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) rethrow;
      // Conversion is optional: do not hide valid store offers when FX fails.
      return null;
    }
  }
}
