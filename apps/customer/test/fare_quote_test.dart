import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrop_customer/models/fare_quote.dart';

void main() {
  group('FareQuote.fromJson', () {
    test('parses distance, fare and breakdown lines', () {
      final q = FareQuote.fromJson({
        'distance_km': 5.4,
        'fare_paise': 5000,
        'platform_fee_paise': 250,
        'rider_earning_paise': 4750,
        'breakdown': [
          {'label': 'Base fare (first 3.0 km)', 'amount_paise': 3000},
          {'label': 'Distance fare (3 km × ₹10.00)', 'amount_paise': 2000},
        ],
      });
      expect(q.distanceKm, 5.4);
      expect(q.farePaise, 5000);
      expect(q.breakdown, hasLength(2));
      expect(q.breakdown[0].label, 'Base fare (first 3.0 km)');
      expect(q.breakdown[0].amountPaise, 3000);
      expect(q.breakdown[1].amountPaise, 2000);
    });

    test('empty breakdown list is fine', () {
      final q = FareQuote.fromJson({
        'distance_km': 2.0,
        'fare_paise': 3000,
        'breakdown': [],
      });
      expect(q.breakdown, isEmpty);
      expect(q.farePaise, 3000);
    });

    test('base fare only for short trips', () {
      final q = FareQuote.fromJson({
        'distance_km': '2.5', // string decimal from Laravel
        'fare_paise': 3000,
        'breakdown': [
          {'label': 'Base fare (first 3.0 km)', 'amount_paise': 3000},
          {'label': 'Distance fare (0 km × ₹10.00)', 'amount_paise': 0},
        ],
      });
      expect(q.distanceKm, 2.5);
      expect(q.farePaise, 3000);
    });
  });
}
