import '../utils/json.dart';

/// Delivery-partner profile, from the /api/v1/rider/* endpoints.

class RiderProfile {
  RiderProfile({
    required this.userId,
    this.aadhaar,
    this.licenceNo,
    this.bikeRc,
    this.bikeNumber,
    this.bankAccount,
    required this.verificationStatus,
    required this.rating,
    required this.totalTrips,
    required this.isOnline,
    this.lastLat,
    this.lastLng,
  });

  factory RiderProfile.fromJson(Map<String, dynamic> json) {
    return RiderProfile(
      userId: jsonInt(json['user_id']),
      aadhaar: json['aadhaar'] as String?,
      licenceNo: json['licence_no'] as String?,
      bikeRc: json['bike_rc'] as String?,
      bikeNumber: json['bike_number'] as String?,
      bankAccount: json['bank_account'] as String?,
      verificationStatus: json['verification_status'] as String? ?? 'pending',
      rating: jsonDouble(json['rating']),
      totalTrips: jsonInt(json['total_trips']),
      isOnline: json['is_online'] == true || json['is_online'] == 1,
      lastLat: jsonDoubleOrNull(json['last_lat']),
      lastLng: jsonDoubleOrNull(json['last_lng']),
    );
  }

  final int userId;
  final String? aadhaar;
  final String? licenceNo;
  final String? bikeRc;
  final String? bikeNumber;
  final String? bankAccount;
  final String verificationStatus;
  final double rating;
  final int totalTrips;
  final bool isOnline;
  final double? lastLat;
  final double? lastLng;

  bool get isApproved => verificationStatus == 'approved';
  bool get isPending => verificationStatus == 'pending';
  bool get isRejected => verificationStatus == 'rejected';

  /// How many of the 5 KYC documents are filled in.
  int get documentsCompleted {
    var n = 0;
    if ((aadhaar ?? '').isNotEmpty) n++;
    if ((licenceNo ?? '').isNotEmpty) n++;
    if ((bikeRc ?? '').isNotEmpty) n++;
    if ((bikeNumber ?? '').isNotEmpty) n++;
    if ((bankAccount ?? '').isNotEmpty) n++;
    return n;
  }
}
