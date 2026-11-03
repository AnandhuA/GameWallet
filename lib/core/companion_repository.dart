import 'package:hive_ce/hive.dart';
import 'companion_models.dart';
import 'storage.dart';

class CompanionRepository {
  final AppStorage storage;
  CompanionRepository(this.storage);
  Box<dynamic> get box => storage.personal ?? storage.preferences;
  List<Map<String, dynamic>> records(String kind) => box.keys
      .where((k) => k is String && k.startsWith('$kind:'))
      .map((k) => jsonMap(box.get(k)))
      .toList();
  Future<void> put(String kind, String id, Map<String, dynamic> data) =>
      box.put('$kind:$id', data);
  Future<void> remove(String kind, String id) => box.delete('$kind:$id');
  String newId() => DateTime.now().microsecondsSinceEpoch.toString();
  Future<void> migrateJournal() async {
    for (final old in storage.library.values.toList()) {
      final marker = 'migrated:${old.game.key}';
      if (box.get(marker) == true) {
        continue;
      }
      if (old.notes.isNotEmpty || old.personalRating != null) {
        final id = 'import:${old.game.key}';
        if (!box.containsKey('journal:$id')) {
          await box.put('backup:$id', old.toJson());
          final entry = PlaythroughEntry(
            id: id,
            game: old.game,
            notes: old.notes,
            rating: old.personalRating == null ? null : old.personalRating! / 2,
            createdAt: old.updated,
            updatedAt: old.updated,
            imported: true,
          );
          await put('journal', id, entry.toJson());
        }
        final verified = PlaythroughEntry.fromJson(
          jsonMap(box.get('journal:$id')),
        );
        if (verified.game.key != old.game.key ||
            verified.notes != old.notes ||
            verified.rating !=
                (old.personalRating == null ? null : old.personalRating! / 2)) {
          throw StateError(
            'Journal migration verification failed. Original data is preserved.',
          );
        }
      }
      // Only complete the marker after the copy can be decoded and verified.
      await box.put(marker, true);
    }
  }

  Future<void> prepare() async {
    final version = box.get('companionSchema', defaultValue: 1) as int;
    if (version > 1) {
      throw StateError('Personal data needs a newer Game Wallet version.');
    }
    await migrateJournal();
    await box.put('companionSchema', 1);
  }
}
