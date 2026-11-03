import 'package:flutter/material.dart';
import '../../core/storage.dart';
import '../../core/game_repository.dart';
import '../../core/models.dart';

class SettingsProvider extends ChangeNotifier {
  final AppStorage storage;
  final GameRepository repository;
  SettingsProvider(this.storage, this.repository);
  int connectionRevision = 0;
  bool get needsOnboarding =>
      storage.preferences.get('onboardingDismissed', defaultValue: true) ==
          false &&
      !setupComplete;
  Future<void> dismissOnboarding() async {
    await storage.preferences.put('onboardingDismissed', true);
    notifyListeners();
  }

  int get metadataCacheCount => storage.cache.length;
  int get cacheHours => storage.expiry.inHours;
  String get libraryLayout {
    final value = storage.preferences.get(
      'libraryLayout',
      defaultValue: 'compact',
    );
    return ['compact', 'grid', 'list'].contains(value)
        ? value as String
        : 'compact';
  }

  Future<void> setLibraryLayout(String value) async {
    if (!['compact', 'grid', 'list'].contains(value)) {
      throw ArgumentError('Unknown layout');
    }
    await storage.preferences.put('libraryLayout', value);
    notifyListeners();
  }

  int gridColumns(String screen) {
    final value = storage.preferences.get(
      '${screen}GridColumns',
      defaultValue: 0,
    );
    return value is int && [0, 2, 3, 4, 5].contains(value) ? value : 0;
  }

  Future<void> setGridColumns(String screen, int columns) async {
    if (!['explore', 'library'].contains(screen) ||
        ![0, 2, 3, 4, 5].contains(columns)) {
      throw ArgumentError('Unknown grid preference');
    }
    await storage.preferences.putAll({
      '${screen}GridColumns': columns,
      if (screen == 'library' && libraryLayout == 'list')
        'libraryLayout': 'compact',
    });
    notifyListeners();
  }

  Color get accentColor => Color(
    storage.preferences.get('accentColor', defaultValue: 0xFF06B6D4) as int,
  );
  List<String> get genres =>
      (storage.preferences.get('preferredGenres', defaultValue: <String>[])
              as List)
          .cast<String>();
  bool get setupComplete =>
      storage.preferences.get('setupComplete', defaultValue: false) as bool;
  Future<void> setAccentColor(int value) async {
    await storage.preferences.put('accentColor', value);
    notifyListeners();
  }

  Future<void> saveSetup(
    String name,
    List<String> genreNames,
    List<String> platformIds,
  ) async {
    if (name.trim().isEmpty || name.trim().length > 40) {
      throw ArgumentError('Enter a name between 1 and 40 characters.');
    }
    await storage.preferences.putAll({
      'displayName': name.trim(),
      'preferredGenres': genreNames,
      'platforms': platformIds,
      'setupComplete': true,
      'onboardingDismissed': true,
      'platformSource': demo ? 'demo' : 'rawg',
      'platforms:${demo ? 'demo' : 'rawg'}': platformIds,
    });
    notifyListeners();
  }

  String get displayName =>
      storage.preferences.get('displayName', defaultValue: 'Player') as String;
  Future<void> setDisplayName(String value) async {
    final name = value.trim();
    if (name.isEmpty || name.length > 40) {
      throw ArgumentError('Enter a name between 1 and 40 characters.');
    }
    await storage.preferences.put('displayName', name);
    notifyListeners();
  }

  bool get hasApiKey =>
      (storage.preferences.get(
                'rawgApiKey',
                defaultValue: const String.fromEnvironment('RAWG_API_KEY'),
              )
              as String)
          .trim()
          .isNotEmpty;
  Future<void> saveApiKey(String value) async {
    final key = value.trim();
    await repository.api.validateKey(key);
    await storage.preferences.put('rawgApiKey', key);
    if (storage.preferences.get('platformSource') == 'demo') {
      await storage.preferences.put('platforms', <String>[]);
    }
    await storage.preferences.put('demo', false);
    connectionRevision++;
    notifyListeners();
  }

  Future<CatalogFilters> loadPlatforms() => repository.filters(demo);
  ThemeMode get theme => ThemeMode.values.byName(
    storage.preferences.get('theme', defaultValue: 'dark') as String,
  );
  bool get demo =>
      storage.preferences.get('demo', defaultValue: !hasApiKey) as bool;
  List<String> get platforms {
    final stored = storage.preferences.get(
      'platforms:${demo ? 'demo' : 'rawg'}',
    );
    if (stored is List) return stored.cast<String>();
    final source = storage.preferences.get('platformSource');
    if (source != null && source != (demo ? 'demo' : 'rawg')) return [];
    return (storage.preferences.get('platforms', defaultValue: <String>[])
            as List)
        .cast<String>();
  }

  bool matchesPlatforms(Game game, CatalogFilters filters) {
    final selected = platforms;
    if (selected.isEmpty) return true;
    return selected.any(
      (id) => game.platforms.contains(filters.platforms[id] ?? id),
    );
  }

  Future<void> setTheme(ThemeMode value) async {
    await storage.preferences.put('theme', value.name);
    notifyListeners();
  }

  Future<void> setDemo(bool value) async {
    await storage.preferences.put('demo', value);
    notifyListeners();
  }

  Future<void> setPlatforms(List<String> value) async {
    await storage.preferences.putAll({
      'platforms': value,
      'platformSource': demo ? 'demo' : 'rawg',
      'platforms:${demo ? 'demo' : 'rawg'}': value,
    });
    notifyListeners();
  }

  Future<void> clearCache() async {
    await storage.clearCache();
    notifyListeners();
  }
}
