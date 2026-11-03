import 'package:dio/dio.dart';
import 'models.dart';

class ApiFailure implements Exception {
  final String message;
  const ApiFailure(this.message);
  @override
  String toString() => message;
}

/// Direct RAWG client. No Twitch credentials, proxy, or local server required.
class ApiService {
  final Dio dio;
  final String Function() apiKey;
  ApiService({Dio? client, String Function()? apiKey})
    : apiKey = apiKey ?? (() => const String.fromEnvironment('RAWG_API_KEY')),
      dio =
          client ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.rawg.io/api',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
            ),
          );

  Future<Map<String, dynamic>> _request(
    String path,
    Map<String, dynamic> query, {
    CancelToken? cancel,
    String? key,
  }) async {
    final credential = (key ?? apiKey()).trim();
    if (credential.isEmpty) {
      throw const ApiFailure(
        'Add your free RAWG API key in Settings to load real games. No backend is required.',
      );
    }
    try {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: {...query, 'key': credential},
        cancelToken: cancel,
      );
      if (response.data is! Map) {
        throw const ApiFailure('RAWG returned an invalid response. Try again.');
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        rethrow;
      }
      if ([401, 403].contains(e.response?.statusCode)) {
        throw const ApiFailure(
          'RAWG rejected this API key. Update it in Settings.',
        );
      }
      if (e.response?.statusCode == 429) {
        throw const ApiFailure('RAWG request limit reached. Try again later.');
      }
      if (e.response?.statusCode == 404) {
        throw const ApiFailure('This game is no longer available on RAWG.');
      }
      throw const ApiFailure(
        'Cannot reach RAWG. Check your internet connection and try again.',
      );
    }
  }

  List<Map<String, dynamic>> _results(Map<String, dynamic> data) {
    final items = data['results'];
    if (items is! List || items.any((e) => e is! Map)) {
      throw const ApiFailure('RAWG returned invalid catalog data.');
    }
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> validateKey(String key) async {
    _results(await _request('/games', {'page_size': 1}, key: key));
  }

  Future<dynamic> get(
    String path,
    Map<String, dynamic> query, {
    CancelToken? cancel,
  }) async {
    if (path == '/filters') {
      final data = await Future.wait([
        _request('/genres', {'page_size': 40}, cancel: cancel),
        _request('/platforms', {'page_size': 100}, cancel: cancel),
      ]);
      return {'genres': _results(data[0]), 'platforms': _results(data[1])};
    }
    if (path == '/games') {
      final now = DateTime.now().toUtc();
      String date(DateTime d) => d.toIso8601String().split('T').first;
      final feed = query['feed'];
      final year = query['year'] as int?;
      final sort = query['sort'];
      final search = (query['q'] as String? ?? '').trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      // RAWG's "added" count is collection activity, not a fabricated rating.
      final params = <String, dynamic>{
        'page': (query['page'] as int? ?? 0) + 1,
        'page_size': 20,
        if (search.isEmpty || sort != 'relevance')
          'ordering': feed == 'upcoming'
              ? 'released'
              : feed == 'recent' || sort == 'release'
              ? '-released'
              : sort == 'rating'
              ? '-rating'
              : '-added',
        if (search.isNotEmpty) 'search': search,
        'genres': ?query['genre'],
        'platforms': ?query['platform'],
        if (year != null)
          'dates': '$year-01-01,$year-12-31'
        else if (feed == 'recent')
          'dates':
              '${date(now.subtract(const Duration(days: 180)))},${date(now)}'
        else if (feed == 'upcoming')
          'dates':
              '${date(now.add(const Duration(days: 1)))},${date(DateTime.utc(now.year + 5, 12, 31))}',
      };
      final data = await _request('/games', params, cancel: cancel);
      return {
        'games': _results(data).map((g) => normalize(g).toJson()).toList(),
        'hasMore':
            data['next'] is String && (data['next'] as String).isNotEmpty,
      };
    }
    final data = await _request(path, {}, cancel: cancel);
    List<String> screenshots;
    try {
      final images = await _request('$path/screenshots', {
        'page_size': 20,
      }, cancel: cancel);
      screenshots = _results(
        images,
      ).map((s) => secureUrl(s['image'])).whereType<String>().toList();
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        rethrow;
      }
      screenshots = [];
    }
    return {'game': normalize(data, screenshots: screenshots).toJson()};
  }

  static String? secureUrl(dynamic value) {
    if (value is! String) {
      return null;
    }
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? value
        : null;
  }

  static Game normalize(Map<String, dynamic> j, {List<String>? screenshots}) {
    if (j['id'] is! int || j['name'] is! String) {
      throw const ApiFailure('RAWG returned invalid game metadata.');
    }
    List<String> names(dynamic items) => (items is List ? items : const [])
        .whereType<Map>()
        .map((v) => v['name'])
        .whereType<String>()
        .toList();
    final cover = secureUrl(j['background_image']);
    return Game(
      id: j['id'] as int,
      title: j['name'] as String,
      source: 'rawg',
      summary: j['description_raw'] as String? ?? '',
      cover: cover,
      artwork: secureUrl(j['background_image_additional']) ?? cover,
      rating: j['rating'] is num && (j['ratings_count'] as num? ?? 0) > 0
          ? (j['rating'] as num).toDouble() * 20
          : null,
      release: DateTime.tryParse(j['released'] as String? ?? ''),
      genres: names(j['genres']),
      platforms: names(
        (j['platforms'] as List? ?? [])
            .whereType<Map>()
            .map((p) => p['platform'])
            .toList(),
      ),
      developers: names(j['developers']),
      publishers: names(j['publishers']),
      screenshots:
          screenshots ??
          (j['short_screenshots'] as List? ?? [])
              .whereType<Map>()
              .map((s) => secureUrl(s['image']))
              .whereType<String>()
              .toList(),
      // Trailer/store/similar endpoints are not included in RAWG's advertised free tier.
      links: [if (secureUrl(j['website']) case final String url) url],
    );
  }
}
