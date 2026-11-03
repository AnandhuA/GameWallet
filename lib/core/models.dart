import 'package:hive_ce/hive.dart';

class Game {
  final int id;
  final String title, summary;
  final String? cover, artwork;
  final double? rating;
  final DateTime? release;
  final List<String> genres,
      platforms,
      developers,
      publishers,
      screenshots,
      trailers,
      links;
  final List<int> similar;
  final bool demo;
  final String source;
  const Game({
    required this.id,
    required this.title,
    this.summary = '',
    this.cover,
    this.artwork,
    this.rating,
    this.release,
    this.genres = const [],
    this.platforms = const [],
    this.developers = const [],
    this.publishers = const [],
    this.screenshots = const [],
    this.trailers = const [],
    this.links = const [],
    this.similar = const [],
    this.demo = false,
    this.source = 'igdb',
  });
  String get key => '${demo ? 'demo' : source}:$id';
  factory Game.fromJson(Map<String, dynamic> j) => Game(
    id: j['id'] as int,
    title: j['title'] as String? ?? 'Untitled',
    summary: j['summary'] as String? ?? '',
    cover: j['cover'] as String?,
    artwork: j['artwork'] as String?,
    rating: (j['rating'] as num?)?.toDouble(),
    release: DateTime.tryParse(j['release'] as String? ?? ''),
    genres: strings(j['genres']),
    platforms: strings(j['platforms']),
    developers: strings(j['developers']),
    publishers: strings(j['publishers']),
    screenshots: strings(j['screenshots']),
    trailers: strings(j['trailers']),
    links: strings(j['links']),
    similar: (j['similar'] as List? ?? []).cast<int>(),
    demo: j['demo'] == true,
    source: j['source'] as String? ?? 'igdb',
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'cover': cover,
    'artwork': artwork,
    'rating': rating,
    'release': release?.toIso8601String(),
    'genres': genres,
    'platforms': platforms,
    'developers': developers,
    'publishers': publishers,
    'screenshots': screenshots,
    'trailers': trailers,
    'links': links,
    'similar': similar,
    'demo': demo,
    'source': source,
  };
  static List<String> strings(dynamic value) =>
      (value as List? ?? []).cast<String>();
}

enum LibraryStatus { wantToPlay, playing, completed, dropped }

extension StatusLabel on LibraryStatus {
  String get label =>
      ['Want to Play', 'Playing', 'Completed', 'Dropped'][index];
}

DateTime calendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);
String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
int inclusiveDays(DateTime start, DateTime end) =>
    DateTime.utc(
      end.year,
      end.month,
      end.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays +
    1;

class GamePlaythrough {
  final String id;
  final DateTime? startDate, endDate;
  final bool completed;
  const GamePlaythrough({
    required this.id,
    this.startDate,
    this.endDate,
    this.completed = false,
  });
  int? days(DateTime today) =>
      startDate == null || (completed && endDate == null)
      ? null
      : inclusiveDays(startDate!, completed ? endDate! : today);
  Map<String, dynamic> toJson() => {
    'id': id,
    'startDate': startDate == null ? null : dateKey(startDate!),
    'endDate': endDate == null ? null : dateKey(endDate!),
    'completed': completed,
  };
  factory GamePlaythrough.fromJson(Map<String, dynamic> j) => GamePlaythrough(
    id: j['id'] as String,
    startDate: DateTime.tryParse(j['startDate'] as String? ?? ''),
    endDate: DateTime.tryParse(j['endDate'] as String? ?? ''),
    completed: j['completed'] == true,
  );
}

class LibraryEntry {
  final Game game;
  final bool favorite;
  final bool bookmarked;
  final int completedRuns;
  final List<GamePlaythrough> playthroughs;
  final String? activePlaythroughId;
  final LibraryStatus? status;
  final String notes;
  final int? personalRating;
  final DateTime updated;
  LibraryEntry({
    required this.game,
    this.favorite = false,
    this.bookmarked = true,
    int? completedRuns,
    this.playthroughs = const [],
    this.activePlaythroughId,
    this.status,
    this.notes = '',
    this.personalRating,
    DateTime? updated,
  }) : completedRuns =
           completedRuns ?? (status == LibraryStatus.completed ? 1 : 0),
       updated = updated ?? DateTime.now();
  factory LibraryEntry.fromJson(Map<String, dynamic> j) => LibraryEntry(
    game: Game.fromJson(Map<String, dynamic>.from(j['game'] as Map)),
    favorite: j['favorite'] == true,
    bookmarked: j['bookmarked'] as bool? ?? true,
    completedRuns: j['completedRuns'] as int?,
    playthroughs: (j['playthroughs'] as List? ?? [])
        .map((r) => GamePlaythrough.fromJson(Map<String, dynamic>.from(r)))
        .toList(),
    activePlaythroughId: j['activePlaythroughId'] as String?,
    status: j['status'] == null
        ? null
        : LibraryStatus.values.byName(j['status']),
    notes: j['notes'] as String? ?? '',
    personalRating: j['personalRating'] as int?,
    updated: DateTime.tryParse(j['updated'] as String? ?? ''),
  );
  Map<String, dynamic> toJson() => {
    'game': game.toJson(),
    'favorite': favorite,
    'bookmarked': bookmarked,
    'completedRuns': completedRuns,
    'playthroughs': playthroughs.map((r) => r.toJson()).toList(),
    'activePlaythroughId': activePlaythroughId,
    'status': status?.name,
    'notes': notes,
    'personalRating': personalRating,
    'updated': updated.toIso8601String(),
  };
}

// Type IDs and field names are stable. Add optional fields with defaults; never reuse IDs.
class LibraryEntryAdapter extends TypeAdapter<LibraryEntry> {
  @override
  int get typeId => 1;
  @override
  LibraryEntry read(BinaryReader reader) =>
      LibraryEntry.fromJson(Map<String, dynamic>.from(reader.readMap()));
  @override
  void write(BinaryWriter writer, LibraryEntry obj) =>
      writer.writeMap(obj.toJson());
}

class CatalogResult {
  final List<Game> games;
  final bool hasMore, stale;
  const CatalogResult(this.games, {this.hasMore = false, this.stale = false});
}

class CatalogFilters {
  final Map<String, String> genres, platforms;
  const CatalogFilters(this.genres, this.platforms);
}
