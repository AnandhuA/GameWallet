import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'price_models.dart';

class PricingService {
  final Dio dio;
  final DateTime Function() clock;
  final Map<String, DateTime> _retryAt = {};
  PricingService({Dio? dio, DateTime Function()? clock})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://www.cheapshark.com/api/1.0',
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 15),
              // Browsers manage User-Agent; setting it there is forbidden.
              headers: {
                if (!kIsWeb)
                  'User-Agent': 'GameWallet/2.2 (Flutter game companion)',
              },
            ),
          ),
      clock = clock ?? DateTime.now;

  Future<dynamic> get(
    String path,
    Map<String, dynamic> query,
    CancelToken cancel,
  ) async {
    final host = Uri.parse(path).host.isEmpty
        ? Uri.parse(dio.options.baseUrl).host
        : Uri.parse(path).host;
    if (_retryAt[host] case final DateTime until when clock().isBefore(until)) {
      throw PricingFailure(
        'Price requests are temporarily limited. Try again later.',
        retryAt: until,
      );
    }
    try {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: query,
        cancelToken: cancel,
      );
      return response.data;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      if (e.response?.statusCode == 429) {
        final retry = e.response?.headers.value('retry-after');
        final seconds = int.tryParse(retry ?? '');
        _retryAt[host] = seconds != null && seconds >= 0
            ? clock().add(Duration(seconds: seconds))
            : _httpDate(retry) ?? clock().add(const Duration(minutes: 1));
        throw PricingFailure(
          'Price requests are temporarily limited. Try again later.',
          retryAt: _retryAt[host],
        );
      }
      throw const PricingFailure(
        'Could not check store prices. Check your connection and try again.',
      );
    }
  }

  static DateTime? _httpDate(String? value) {
    // RFC 7231 HTTP-date, without dart:io so this service also runs on web.
    final parts = RegExp(
      r'^\w{3}, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(value ?? '');
    if (parts == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months.indexOf(parts[2]!);
    if (month < 0) return null;
    return DateTime.utc(
      int.parse(parts[3]!),
      month + 1,
      int.parse(parts[1]!),
      int.parse(parts[4]!),
      int.parse(parts[5]!),
      int.parse(parts[6]!),
    );
  }

  void dispose() => dio.close(force: true);
}
