import 'dart:convert';
import 'package:dio/dio.dart';

class DealsService {
  static const feedUrl =
      'https://raw.githubusercontent.com/josephmate/EpicFreeGamesList/main/epic_free_games.json';
  final Dio dio;
  DealsService({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );
  Future<dynamic> fetch(CancelToken cancel) async {
    final response = await dio.get<dynamic>(feedUrl, cancelToken: cancel);
    return response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
  }

  void dispose() => dio.close(force: true);
}
