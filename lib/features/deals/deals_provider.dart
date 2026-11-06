import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'deal_record.dart';
import 'deals_repository.dart';

class DealsProvider extends ChangeNotifier {
  final DealsRepository repository;
  DealsProvider(this.repository);
  DealsSnapshot? snapshot;
  bool loading = false;
  int artworkRevision = 0;
  String? error;
  String query = '', platform = 'all';
  CancelToken? _cancel;
  bool _disposed = false;
  List<DealRecord> get visible => (snapshot?.records ?? <DealRecord>[])
      .where(
        (e) =>
            (platform == 'all' || e.platform == platform) &&
            e.title.toLowerCase().contains(query.trim().toLowerCase()),
      )
      .toList();
  void filter({String? text, String? platformValue}) {
    if (text != null) query = text;
    if (platformValue != null) platform = platformValue;
    notifyListeners();
  }

  Future<void> load({bool refresh = false}) async {
    if (_disposed || (loading && !refresh)) return;
    if (refresh) artworkRevision++;
    _cancel?.cancel('Superseded feed request');
    final cancel = _cancel = CancelToken();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await repository.load(cancel, refresh: refresh);
      if (!_disposed && identical(_cancel, cancel)) snapshot = result;
    } catch (_) {
      if (!_disposed && identical(_cancel, cancel) && !cancel.isCancelled) {
        final previous = snapshot;
        if (previous != null) {
          snapshot = DealsSnapshot(
            previous.records,
            previous.fetchedAt,
            stale: true,
          );
        }
        error =
            'Could not load giveaway records. Check your connection and retry.';
      }
    } finally {
      if (!_disposed && identical(_cancel, cancel)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel?.cancel('Deals closed');
    super.dispose();
  }
}
