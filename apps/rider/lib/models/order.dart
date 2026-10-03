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
      id: (json['id'] as num).toInt(),
      customerId: (json['customer_id'] as num?)?.toInt(),
      riderId: (json['rider_id'] as num?)?.toInt(),
      pickupAddress: json['pickup_address'] as String? ?? '',
      pickupLat: (json['pickup_lat'] as num?)?.toDouble() ?? 0,
      pickupLng: (json['pickup_lng'] as num?)?.toDouble() ?? 0,
      dropAddress: json['drop_address'] as String? ?? '',
      dropLat: (json['drop_lat'] as num?)?.toDouble() ?? 0,
      dropLng: (json['drop_lng'] as num?)?.toDouble() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      farePaise: (json['fare_paise'] as num?)?.toInt() ?? 0,
      platformFeePaise: (json['platform_fee_paise'] as num?)?.toInt() ?? 0,
      riderEarningPaise: (json['rider_earning_paise'] as num?)?.toInt() ?? 0,
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
