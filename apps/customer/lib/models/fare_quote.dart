import '../utils/json.dart';

/// Server-computed fare quote from POST /api/v1/fare/quote.
/// Money is in PAISE (integers). The client never decides the price.

class FareQuote {
  FareQuote({
    required this.distanceKm,
    required this.farePaise,
    required this.breakdown,
  });

  factory FareQuote.fromJson(Map<String, dynamic> json) {
    final raw = json['breakdown'];
    final items = <FareLine>[];
    if (raw is List) {
      for (final e in raw.whereType<Map<String, dynamic>>()) {
        items.add(FareLine.fromJson(e));
      }
    }
    return FareQuote(
      distanceKm: jsonDouble(json['distance_km']),
      farePaise: jsonInt(json['fare_paise']),
      breakdown: items,
    );
  }

  final double distanceKm;
  final int farePaise;
  final List<FareLine> breakdown;
}

class FareLine {
  FareLine({required this.label, required this.amountPaise});

  factory FareLine.fromJson(Map<String, dynamic> json) {
    return FareLine(
      label: json['label'] as String? ?? '',
      amountPaise: jsonInt(json['amount_paise']),
    );
  }

  final String label;
  final int amountPaise;
}
