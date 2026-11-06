/// A source record, not a verified current offer or a personal library game.
class DealRecord {
  final String title, platform, storeUrl, source;
  final DateTime recordedDate;
  final double? rating;
  final int? criticScore;
  final String? steamUrl;
  const DealRecord({
    required this.title,
    required this.platform,
    required this.storeUrl,
    required this.recordedDate,
    this.rating,
    this.criticScore,
    this.source = 'Epic Games',
    this.steamUrl,
  });
  String get key => '$storeUrl|$platform|$dateLabel';
  String get dateLabel => recordedDate.toIso8601String().substring(0, 10);
  String? get steamAppId {
    final uri = Uri.tryParse(steamUrl ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'store.steampowered.com' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      return null;
    }
    return RegExp(r'^/app/([1-9]\d*)(?:/|$)').firstMatch(uri.path)?.group(1);
  }

  List<String> get coverSources => steamAppId == null
      ? []
      : [
          'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/$steamAppId/library_600x900.jpg',
          'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/$steamAppId/header.jpg',
        ];

  static bool safeStoreUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'store.epicgames.com' &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443) &&
        uri.path.contains('/p/');
  }

  static DealRecord? fromEpic(dynamic value) {
    if (value is! Map) return null;
    final title = value['gameTitle'];
    final url = value['epicStoreLink'];
    final rawDate = value['freeDate'];
    if (title is! String ||
        title.trim().isEmpty ||
        url is! String ||
        !safeStoreUrl(url) ||
        rawDate is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate)) {
      return null;
    }
    final date = DateTime.tryParse(rawDate);
    if (date == null || date.toIso8601String().substring(0, 10) != rawDate) {
      return null;
    }
    final rawPlatform = value['platform'];
    final platform = rawPlatform is String
        ? rawPlatform.trim().toLowerCase()
        : '';
    final score = value['epicRating'];
    final critic = value['metacriticScore'];
    return DealRecord(
      title: title.trim(),
      storeUrl: url,
      recordedDate: date,
      platform: ['pc', 'android', 'ios'].contains(platform)
          ? platform
          : 'unknown',
      rating: score is num && score.isFinite && score > 0 && score <= 5
          ? score.toDouble()
          : null,
      criticScore:
          critic is num &&
              critic.isFinite &&
              critic > 0 &&
              critic <= 100 &&
              critic == critic.round()
          ? critic.toInt()
          : null,
      steamUrl: value['steamUrl'] is String
          ? value['steamUrl'] as String
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'gameTitle': title,
    'platform': platform,
    'epicStoreLink': storeUrl,
    'freeDate': dateLabel,
    'epicRating': rating,
    'metacriticScore': criticScore,
    'steamUrl': steamUrl,
  };
}

List<DealRecord> parseEpicRecords(dynamic data) {
  if (data is! List) throw const FormatException('Invalid giveaway feed');
  final records = <String, DealRecord>{};
  for (final raw in data) {
    final record = DealRecord.fromEpic(raw);
    if (record != null) records.putIfAbsent(record.key, () => record);
  }
  if (data.isNotEmpty && records.isEmpty) {
    throw const FormatException('No valid giveaway records');
  }
  final sorted = records.values.toList()
    ..sort((a, b) {
      final date = b.recordedDate.compareTo(a.recordedDate);
      return date != 0 ? date : a.key.compareTo(b.key);
    });
  return sorted;
}
