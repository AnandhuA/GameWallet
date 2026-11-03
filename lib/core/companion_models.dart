import 'models.dart';

Map<String, dynamic> jsonMap(dynamic value) =>
    Map<String, dynamic>.from(value as Map);
List<Game> gameList(dynamic value) =>
    (value as List? ?? []).map((e) => Game.fromJson(jsonMap(e))).toList();
DateTime? dateValue(dynamic value) => DateTime.tryParse(value as String? ?? '');

class GameLineUp {
  final String id, title, description;
  final List<Game> games;
  final int color;
  final String? coverKey;
  final bool favorite, starter, demo;
  const GameLineUp({
    required this.id,
    required this.title,
    this.description = '',
    this.games = const [],
    this.color = 0xFF06B6D4,
    this.coverKey,
    this.favorite = false,
    this.starter = false,
    this.demo = false,
  });
  GameLineUp copy({
    String? id,
    String? title,
    String? description,
    List<Game>? games,
    int? color,
    String? coverKey,
    bool? favorite,
    bool? starter,
  }) => GameLineUp(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    games: games ?? this.games,
    color: color ?? this.color,
    coverKey: coverKey ?? this.coverKey,
    favorite: favorite ?? this.favorite,
    starter: starter ?? this.starter,
    demo: demo,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'games': games.map((g) => g.toJson()).toList(),
    'color': color,
    'coverKey': coverKey,
    'favorite': favorite,
    'starter': starter,
    'demo': demo,
  };
  factory GameLineUp.fromJson(Map<String, dynamic> j) => GameLineUp(
    id: j['id'],
    title: j['title'],
    description: j['description'] ?? '',
    games: gameList(j['games']),
    color: j['color'] ?? 0xFF06B6D4,
    coverKey: j['coverKey'],
    favorite: j['favorite'] == true,
    starter: j['starter'] == true,
    demo: j['demo'] == true,
  );
}

class PlaythroughEntry {
  final String id, review, notes, moment, quote, recommendation;
  final Game game;
  final String? playthroughId;
  final double? rating;
  final DateTime? playedOn;
  final DateTime createdAt, updatedAt;
  final List<String> reactions, tags;
  final bool imported;
  PlaythroughEntry({
    required this.id,
    required this.game,
    this.playthroughId,
    this.review = '',
    this.notes = '',
    this.moment = '',
    this.quote = '',
    this.recommendation = 'maybe',
    this.rating,
    this.playedOn,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.reactions = const [],
    this.tags = const [],
    this.imported = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
  Map<String, dynamic> toJson() => {
    'id': id,
    'playthroughId': playthroughId,
    'game': game.toJson(),
    'review': review,
    'notes': notes,
    'moment': moment,
    'quote': quote,
    'recommendation': recommendation,
    'rating': rating,
    'playedOn': playedOn?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reactions': reactions,
    'tags': tags,
    'imported': imported,
  };
  factory PlaythroughEntry.fromJson(Map<String, dynamic> j) => PlaythroughEntry(
    id: j['id'],
    playthroughId: j['playthroughId'] as String?,
    game: Game.fromJson(jsonMap(j['game'])),
    review: j['review'] ?? '',
    notes: j['notes'] ?? '',
    moment: j['moment'] ?? '',
    quote: j['quote'] ?? '',
    recommendation: j['recommendation'] ?? 'maybe',
    rating: (j['rating'] as num?)?.toDouble(),
    playedOn: dateValue(j['playedOn']),
    createdAt: dateValue(j['createdAt']),
    updatedAt: dateValue(j['updatedAt']),
    reactions: Game.strings(j['reactions']),
    tags: Game.strings(j['tags']),
    imported: j['imported'] == true,
  );
}

class PlaySessionPlan {
  final String id, notes;
  final Game game;
  final DateTime scheduled;
  final bool hasTime, completed;
  const PlaySessionPlan({
    required this.id,
    required this.game,
    required this.scheduled,
    this.notes = '',
    this.hasTime = false,
    this.completed = false,
  });
  PlaySessionPlan withCompleted(bool value) => PlaySessionPlan(
    id: id,
    game: game,
    scheduled: scheduled,
    notes: notes,
    hasTime: hasTime,
    completed: value,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'game': game.toJson(),
    'scheduled': scheduled.toIso8601String(),
    'notes': notes,
    'hasTime': hasTime,
    'completed': completed,
  };
  factory PlaySessionPlan.fromJson(Map<String, dynamic> j) => PlaySessionPlan(
    id: j['id'],
    game: Game.fromJson(jsonMap(j['game'])),
    scheduled: DateTime.parse(j['scheduled']),
    notes: j['notes'] ?? '',
    hasTime: j['hasTime'] == true,
    completed: j['completed'] == true,
  );
}
