/// CheapShark identities are separate from the app's catalog identities.
class PriceMatch {
  final String id, title;
  const PriceMatch(this.id, this.title);
  factory PriceMatch.fromJson(Map<String, dynamic> json) {
    final id = json['gameID'];
    final title = json['external'] ?? json['title'];
    if (id is! String ||
        !RegExp(r'^\d+$').hasMatch(id) ||
        title is! String ||
        title.trim().isEmpty) {
      throw const FormatException('Invalid pricing match');
    }
    return PriceMatch(id, title);
  }
  Map<String, dynamic> toJson() => {'gameID': id, 'external': title};
}

String normalizedPriceTitle(String title) => title
    .toLowerCase()
    .replaceAll(RegExp('[™®©]'), '')
    .replaceAll(RegExp(r'[^a-z0-9\u0080-\uffff]+'), ' ')
    .trim();

PriceMatch? exactPriceMatch(String title, List<PriceMatch> matches) {
  final exact = matches
      .where(
        (m) => normalizedPriceTitle(m.title) == normalizedPriceTitle(title),
      )
      .toList();
  return exact.length == 1 ? exact.single : null;
}

class StoreOffer {
  final String storeId, storeName, dealId;

  /// Integer cents avoid rounding errors while ordering prices.
  final int cents;
  final int? retailCents;
  const StoreOffer({
    required this.storeId,
    required this.storeName,
    required this.dealId,
    required this.cents,
    this.retailCents,
  });
  int? get discount => retailCents != null && retailCents! > cents
      ? ((retailCents! - cents) * 100 / retailCents!).round()
      : null;
  Uri get url {
    // CheapShark returns an already percent-encoded ID. Uri encodes the query
    // once; decoding first preserves the provider's redirect ID exactly.
    String decoded;
    try {
      decoded = Uri.decodeComponent(dealId);
    } on FormatException {
      decoded = dealId;
    }
    return Uri.https('www.cheapshark.com', '/redirect', {'dealID': decoded});
  }

  static int? parseCents(dynamic value) {
    if (value is! String || !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
      return null;
    }
    final parts = value.split('.');
    return int.parse(parts[0]) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0')));
  }

  static String money(int cents) => 'US\$${(cents / 100).toStringAsFixed(2)}';
}

class PriceListing {
  final PriceMatch match;
  final List<StoreOffer> offers;
  final DateTime checkedAt;
  final bool stale;
  final RupeeRate? rupeeRate;
  const PriceListing(
    this.match,
    this.offers,
    this.checkedAt, {
    this.stale = false,
    this.rupeeRate,
  });
}

/// Reference conversion of a USD offer, never an Indian store quote.
class RupeeRate {
  final double rate;
  final String date;
  final bool stale;
  const RupeeRate(this.rate, this.date, {this.stale = false});
  factory RupeeRate.fromJson(dynamic json, {bool stale = false}) {
    if (json is! Map ||
        json['base'] != 'USD' ||
        json['quote'] != 'INR' ||
        json['rate'] is! num ||
        !(json['rate'] as num).isFinite ||
        (json['rate'] as num) <= 0 ||
        (json['rate'] as num) > 1000000 ||
        json['date'] is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(json['date'] as String) ||
        DateTime.tryParse(json['date'] as String) == null) {
      throw const FormatException('Invalid USD/INR reference rate');
    }
    if (DateTime.parse(
          json['date'] as String,
        ).toIso8601String().substring(0, 10) !=
        json['date']) {
      throw const FormatException('Invalid exchange rate date');
    }
    return RupeeRate(
      (json['rate'] as num).toDouble(),
      json['date'] as String,
      stale: stale,
    );
  }
  String money(int usdCents) {
    final paise = (usdCents * rate).round();
    final whole = (paise ~/ 100).toString();
    final groups = <String>[];
    var end = whole.length;
    var size = 3;
    while (end > 0) {
      final start = (end - size).clamp(0, end);
      groups.insert(0, whole.substring(start, end));
      end = start;
      size = 2;
    }
    return '≈ ₹${groups.join(',')}.${(paise % 100).toString().padLeft(2, '0')}';
  }
}

class PricingFailure implements Exception {
  final String message;
  final DateTime? retryAt;
  const PricingFailure(this.message, {this.retryAt});
  @override
  String toString() => message;
}
