import '../utils/json.dart';

/// A parcel delivery order. Money is in PAISE (integers).
/// Statuses: requested → assigned → picked_up → delivered (or cancelled).

class ParcelOrder {
  ParcelOrder({
    required this.id,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropAddress,
    required this.dropLat,
    required this.dropLng,
    required this.distanceKm,
    required this.farePaise,
    this.parcelType,
    required this.status,
    this.paymentMode,
    this.riderId,
    this.riderName,
    this.riderPhone,
    this.createdAt,
  });

  factory ParcelOrder.fromJson(Map<String, dynamic> json) {
    final rider = json['rider'];
    return ParcelOrder(
      id: jsonInt(json['id']),
      pickupAddress: json['pickup_address'] as String? ?? '',
      pickupLat: jsonDouble(json['pickup_lat']),
      pickupLng: jsonDouble(json['pickup_lng']),
      dropAddress: json['drop_address'] as String? ?? '',
      dropLat: jsonDouble(json['drop_lat']),
      dropLng: jsonDouble(json['drop_lng']),
      distanceKm: jsonDouble(json['distance_km']),
      farePaise: jsonInt(json['fare_paise']),
      parcelType: json['parcel_type'] as String?,
      status: json['status'] as String? ?? 'requested',
      paymentMode: json['payment_mode'] as String?,
      riderId: jsonIntOrNull(json['rider_id']),
      riderName: rider is Map ? rider['name'] as String? : null,
      riderPhone: rider is Map ? rider['phone'] as String? : null,
      createdAt: json['created_at'] as String?,
    );
  }

  final int id;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropAddress;
  final double dropLat;
  final double dropLng;
  final double distanceKm;
  final int farePaise;
  final String? parcelType;
  final String status;
  final String? paymentMode;
  final int? riderId;
  final String? riderName;
  final String? riderPhone;
  final String? createdAt;

  bool get isRequested => status == 'requested';
  bool get isAssigned => status == 'assigned';
  bool get isPickedUp => status == 'picked_up';
  bool get isDelivered => status == 'delivered';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => isRequested || isAssigned || isPickedUp;

  /// Short display id, e.g. "SD-10492".
  String get displayId => 'SD-${10000 + id}';

  String get statusLabel {
    switch (status) {
      case 'requested':
        return 'Finding rider…';
      case 'assigned':
        return 'Rider assigned';
      case 'picked_up':
        return 'On the way';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
