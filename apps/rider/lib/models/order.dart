import '../utils/json.dart';

/// A delivery order. Money is in PAISE (integers).
/// Statuses: requested → assigned → picked_up → delivered (or cancelled).

class DeliveryOrder {
  DeliveryOrder({
    required this.id,
    this.customerId,
    this.riderId,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropAddress,
    required this.dropLat,
    required this.dropLng,
    required this.distanceKm,
    required this.farePaise,
    required this.platformFeePaise,
    required this.riderEarningPaise,
    this.parcelType,
    required this.status,
    this.paymentMode,
    this.paymentStatus,
    this.assignedAt,
    this.pickupOtpExpiresAt,
    this.deliveredAt,
    this.customerName,
    this.customerPhone,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    return DeliveryOrder(
      id: jsonInt(json['id']),
      customerId: jsonIntOrNull(json['customer_id']),
      riderId: jsonIntOrNull(json['rider_id']),
      pickupAddress: json['pickup_address'] as String? ?? '',
      pickupLat: jsonDouble(json['pickup_lat']),
      pickupLng: jsonDouble(json['pickup_lng']),
      dropAddress: json['drop_address'] as String? ?? '',
      dropLat: jsonDouble(json['drop_lat']),
      dropLng: jsonDouble(json['drop_lng']),
      distanceKm: jsonDouble(json['distance_km']),
      farePaise: jsonInt(json['fare_paise']),
      platformFeePaise: jsonInt(json['platform_fee_paise']),
      riderEarningPaise: jsonInt(json['rider_earning_paise']),
      parcelType: json['parcel_type'] as String?,
      status: json['status'] as String? ?? 'requested',
      paymentMode: json['payment_mode'] as String?,
      paymentStatus: json['payment_status'] as String?,
      assignedAt: json['assigned_at'] as String?,
      pickupOtpExpiresAt: json['pickup_otp_expires_at'] as String?,
      deliveredAt: json['delivered_at'] as String?,
      customerName: customer is Map ? customer['name'] as String? : null,
      customerPhone: customer is Map ? customer['phone'] as String? : null,
    );
  }

  final int id;
  final int? customerId;
  final int? riderId;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropAddress;
  final double dropLat;
  final double dropLng;
  final double distanceKm;
  final int farePaise;
  final int platformFeePaise;
  final int riderEarningPaise;
  final String? parcelType;
  final String status;
  final String? paymentMode;
  final String? paymentStatus;
  final String? assignedAt;
  final String? pickupOtpExpiresAt;
  final String? deliveredAt;
  final String? customerName;
  final String? customerPhone;

  bool get isRequested => status == 'requested';
  bool get isAssigned => status == 'assigned';
  bool get isPickedUp => status == 'picked_up';
  bool get isDelivered => status == 'delivered';

  /// Short display id, e.g. "SD-10492".
  String get displayId => 'SD-${10000 + id}';
}
