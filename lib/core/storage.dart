import 'package:hive_ce_flutter/hive_flutter.dart';
import 'models.dart';

class AppStorage {
  final Box<LibraryEntry> library;
  final Box<dynamic> preferences, cache;
  final Box<dynamic>? personal, images;
  int cacheGeneration = 0;
  final Duration expiry;
  final int cacheLimit;
  final DateTime Function() clock;
  AppStorage(
    this.library,
    this.preferences,
    this.cache, {
    this.personal,
    this.images,
    this.expiry = const Duration(
      hours: int.fromEnvironment('CACHE_HOURS', defaultValue: 24),
    ),
    this.cacheLimit = 200,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;
  static Future<AppStorage> open() async {
    await Hive.initFlutter();
    Hive.registerAdapter(LibraryEntryAdapter());
    final preferences = await Hive.openBox<dynamic>('preferences');
    final fresh = preferences.isEmpty;
    final version = preferences.get('schema', defaultValue: 1) as int;
    if (version > 2) {
      throw StateError(
        'This library was created by a newer version of Game Wallet.',
      );
    }

    if (preferences.get('catalogSource') != 'rawg') {
      await preferences.put('platforms', <String>[]);
      await preferences.put('catalogSource', 'rawg');
    }
    final result = AppStorage(
      await Hive.openBox<LibraryEntry>('library_v1'),
      preferences,
      await Hive.openBox<dynamic>('api_cache_v1'),
      personal: await Hive.openBox<dynamic>('companion_v1'),
      images: await Hive.openBox<dynamic>('image_cache_v1'),
    );
    await result.prepareOnboarding(fresh: fresh);
    await preferences.put('schema', 2);
    return result;
  }

  Future<void> prepareOnboarding({required bool fresh}) async {
    // Legacy live preferences use numeric catalog IDs; demo uses local names.
    // Copy before marking the source, preserving both the old value and any
    // already migrated source-specific selection on repeated launches.
    final oldPlatforms = preferences.get('platforms');
    if (preferences.get('platformSource') == null &&
        oldPlatforms is List &&
        oldPlatforms.isNotEmpty &&
        oldPlatforms.every((p) => p is String)) {
      final source =
          oldPlatforms.every((p) => int.tryParse(p as String) != null)
          ? 'rawg'
          : 'demo';
      final key = 'platforms:$source';
      if (!preferences.containsKey(key)) {
        await preferences.put(key, oldPlatforms);
      }
      await preferences.put('platformSource', source);
    }
    if (!preferences.containsKey('onboardingDismissed')) {
      final hasPersonalData =
          library.isNotEmpty || (personal?.isNotEmpty ?? false);
      await preferences.put('onboardingDismissed', !fresh || hasPersonalData);
    }
  }

  Map<String, dynamic>? cached(String key) {
    final value = cache.get(key);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  bool expired(Map<String, dynamic> value) =>
      clock().difference(
        DateTime.fromMillisecondsSinceEpoch(value['time'] as int),
      ) >=
      expiry;
  Future<void> remember(String key, dynamic data) async {
    await cache.put(key, {
      'time': clock().millisecondsSinceEpoch,
      'data': data,
    });
    while (cache.length > cacheLimit) {
      final oldest = cache.keys.reduce(
        (a, b) => (cache.get(a)['time'] as int) <= (cache.get(b)['time'] as int)
            ? a
            : b,
      );
      await cache.delete(oldest);
    }
  }

  Future<void> clearCache() async {
    cacheGeneration++;
    await cache.clear();
  }
}
