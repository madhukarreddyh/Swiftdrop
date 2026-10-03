import 'order.dart';

/// Rider earnings summary, from GET /api/v1/rider/earnings.
class Earnings {
  Earnings({
    required this.todayPaise,
    required this.weekPaise,
    required this.totalPaise,
    required this.totalTrips,
    required this.recentTrips,
  });

  factory Earnings.fromJson(Map<String, dynamic> json) {
    final trips = json['recent_trips'];
    return Earnings(
      todayPaise: (json['today_paise'] as num?)?.toInt() ?? 0,
      weekPaise: (json['week_paise'] as num?)?.toInt() ?? 0,
      totalPaise: (json['total_paise'] as num?)?.toInt() ?? 0,
      totalTrips: (json['total_trips'] as num?)?.toInt() ?? 0,
      recentTrips: trips is List
          ? trips
              .whereType<Map<String, dynamic>>()
              .map(DeliveryOrder.fromJson)
              .toList()
          : const [],
    );
  }

  final int todayPaise;
  final int weekPaise;
  final int totalPaise;
  final int totalTrips;
  final List<DeliveryOrder> recentTrips;
}
