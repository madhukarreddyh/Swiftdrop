import '../utils/json.dart';
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
      todayPaise: jsonInt(json['today_paise']),
      weekPaise: jsonInt(json['week_paise']),
      totalPaise: jsonInt(json['total_paise']),
      totalTrips: jsonInt(json['total_trips']),
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
