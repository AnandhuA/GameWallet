import 'package:flutter/foundation.dart';
import 'models.dart';
import 'storage.dart';

String catalogTitle(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();
bool confirmedCatalogMatch(Game a, Game b) {
  if (a.demo ||
      b.demo ||
      a.source == b.source ||
      catalogTitle(a.title) != catalogTitle(b.title)) {
    return false;
  }
  final links = a.links
      .map(Uri.tryParse)
      .whereType<Uri>()
      .where((u) => u.scheme == 'https' && u.path.length > 1)
      .map((u) => '${u.host}${u.path.replaceFirst(RegExp(r'/$'), '')}')
      .toSet();
  if (b.links
      .map(Uri.tryParse)
      .whereType<Uri>()
      .any(
        (u) => links.contains(
          '${u.host}${u.path.replaceFirst(RegExp(r'/$'), '')}',
        ),
      )) {
    return true;
  }
  final companies = [
    ...a.developers,
    ...a.publishers,
  ].map(catalogTitle).where((v) => v.isNotEmpty).toSet();
  return a.release != null &&
      b.release != null &&
      a.release!.year == b.release!.year &&
      [
        ...b.developers,
        ...b.publishers,
      ].map(catalogTitle).any(companies.contains);
}

/// Personal identity links survive cache clearing; saved records are never moved.
class CatalogIdentity extends ChangeNotifier {
  final AppStorage storage;
  CatalogIdentity(this.storage);
  Future<void> _writes = Future.value();
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Set<String> keys(String key) {
    final value = (storage.personal ?? storage.preferences).get(
      'catalog-link:$key',
    );
    return {
      key,
      if (value is Map && value['keys'] is List)
        ...(value['keys'] as List).whereType<String>(),
    };
  }

  String canonical(String key) {
    final value = (storage.personal ?? storage.preferences).get(
      'catalog-link:$key',
    );
    return value is Map && value['canonical'] is String
        ? value['canonical'] as String
        : key;
  }

  Future<void> link(Game a, Game b, {String? preferredKey}) {
    final operation = _writes.then((_) => _link(a, b, preferredKey));
    _writes = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<void> _link(Game a, Game b, String? preferredKey) async {
    if (a.demo ||
        b.demo ||
        a.source == b.source ||
        !['rawg', 'freetogame'].contains(a.source) ||
        !['rawg', 'freetogame'].contains(b.source)) {
      throw ArgumentError('Unsupported catalog identity');
    }
    final all = {...keys(a.key), ...keys(b.key)}.toList()..sort();
    final saved = all.where(storage.library.containsKey).toList();
    final existing = all
        .map(canonical)
        .where((k) => !all.contains(k) || keys(k).length > 1)
        .firstOrNull;
    final canonicalKey =
        existing ??
        saved.firstOrNull ??
        (preferredKey != null && all.contains(preferredKey)
            ? preferredKey
            : all.firstWhere(
                (k) => k.startsWith('rawg:'),
                orElse: () => all.first,
              ));
    final data = {'keys': all, 'canonical': canonicalKey};
    await (storage.personal ?? storage.preferences).putAll({
      for (final key in all) 'catalog-link:$key': data,
    });
    if (!_disposed) notifyListeners();
  }
}

Game supplementGame(Game primary, Game extra) {
  final p = primary.toJson(), e = extra.toJson();
  final provenance = {...primary.provenance};
  for (final field in [
    'summary',
    'release',
    'developers',
    'publishers',
    'genres',
    'platforms',
    'links',
    'screenshots',
  ]) {
    final value = p[field];
    if (value == null || value == '' || value is List && value.isEmpty) {
      p[field] = e[field];
      provenance[field] = extra.source;
    }
  }
  p['fallbackImages'] = <String>{
    ...primary.fallbackImages,
    if (extra.cover != null) extra.cover!,
    if (extra.artwork != null) extra.artwork!,
    ...extra.screenshots,
  }.toList();
  if ((p['fallbackImages'] as List).isNotEmpty) {
    provenance['fallbackImages'] = extra.source;
  }
  p['provenance'] = provenance;
  return Game.fromJson(p);
}
