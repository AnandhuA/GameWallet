import 'package:dio/dio.dart';
import '../../core/storage.dart';
import 'deal_record.dart';
import 'deals_service.dart';

class DealsSnapshot {
  final List<DealRecord> records;
  final DateTime fetchedAt;
  final bool stale;
  const DealsSnapshot(this.records, this.fetchedAt, {this.stale = false});
}

class DealsRepository {
  static const cacheKey = 'deals:epic-giveaways:v2';
  static const legacyCacheKey = 'deals:epic-giveaways:v1';
  final AppStorage storage;
  final DealsService service;
  DealsRepository(this.storage, this.service);

  Future<DealsSnapshot> load(CancelToken cancel, {bool refresh = false}) async {
    final generation = storage.cacheGeneration;
    DealsSnapshot? cached;
    try {
      final current = storage.cached(cacheKey);
      final raw = current ?? storage.cached(legacyCacheKey);
      if (raw != null && raw['time'] is int) {
        final time = DateTime.fromMillisecondsSinceEpoch(raw['time'] as int);
        final age = storage.clock().difference(time);
        cached = DealsSnapshot(
          parseEpicRecords(raw['data']),
          time,
          stale:
              current == null ||
              age.isNegative ||
              age >= const Duration(hours: 1),
        );
      }
    } catch (_) {
      /* A malformed cache must not block a fresh request. */
    }
    if (!refresh && cached != null && !cached.stale) return cached;
    try {
      final records = parseEpicRecords(await service.fetch(cancel));
      if (cancel.isCancelled) throw cancel.cancelError!;
      final time = storage.clock();
      if (generation == storage.cacheGeneration) {
        try {
          await storage.remember(
            cacheKey,
            records.map((e) => e.toJson()).toList(),
          );
        } catch (_) {
          /* Cache failures do not discard a successful response. */
        }
      }
      return DealsSnapshot(records, time);
    } catch (_) {
      if (cancel.isCancelled) rethrow;
      if (cached != null) {
        return DealsSnapshot(cached.records, cached.fetchedAt, stale: true);
      }
      rethrow;
    }
  }
}
