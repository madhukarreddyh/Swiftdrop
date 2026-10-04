import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrop_customer/models/order.dart';

void main() {
  Map<String, dynamic> sample({String status = 'requested'}) => {
        'id': 42,
        'pickup_address': 'KPHB Colony, Hyderabad',
        'pickup_lat': 17.4832,
        'pickup_lng': 78.3923,
        'drop_address': 'Madhapur, Hyderabad',
        'drop_lat': 17.4483,
        'drop_lng': 78.3915,
        'distance_km': 5.4,
        'fare_paise': 5000,
        'parcel_type': 'Documents',
        'status': status,
        'payment_mode': 'upi',
        'rider_id': 7,
        'rider': {'id': 7, 'name': 'Ravi Kumar', 'phone': '9876543210'},
        'created_at': '2026-10-04T10:00:00.000000Z',
      };

  group('ParcelOrder.fromJson', () {
    test('parses all fields including nested rider', () {
      final o = ParcelOrder.fromJson(sample(status: 'assigned'));
      expect(o.id, 42);
      expect(o.pickupAddress, 'KPHB Colony, Hyderabad');
      expect(o.pickupLat, 17.4832);
      expect(o.distanceKm, 5.4);
      expect(o.farePaise, 5000);
      expect(o.parcelType, 'Documents');
      expect(o.status, 'assigned');
      expect(o.riderId, 7);
      expect(o.riderName, 'Ravi Kumar');
      expect(o.riderPhone, '9876543210');
    });

    test('displayId is SD- prefixed', () {
      expect(ParcelOrder.fromJson(sample()).displayId, 'SD-10042');
    });

    test('status helpers', () {
      expect(ParcelOrder.fromJson(sample(status: 'requested')).isRequested,
          isTrue);
      expect(ParcelOrder.fromJson(sample(status: 'assigned')).isAssigned,
          isTrue);
      expect(ParcelOrder.fromJson(sample(status: 'picked_up')).isPickedUp,
          isTrue);
      expect(ParcelOrder.fromJson(sample(status: 'delivered')).isDelivered,
          isTrue);
      expect(ParcelOrder.fromJson(sample(status: 'cancelled')).isCancelled,
          isTrue);
      final active = ParcelOrder.fromJson(sample(status: 'picked_up'));
      expect(active.isActive, isTrue);
      expect(
          ParcelOrder.fromJson(sample(status: 'delivered')).isActive, isFalse);
    });

    test('statusLabel is human readable', () {
      expect(ParcelOrder.fromJson(sample(status: 'requested')).statusLabel,
          'Finding rider…');
      expect(ParcelOrder.fromJson(sample(status: 'assigned')).statusLabel,
          'Rider assigned');
      expect(ParcelOrder.fromJson(sample(status: 'picked_up')).statusLabel,
          'On the way');
      expect(ParcelOrder.fromJson(sample(status: 'delivered')).statusLabel,
          'Delivered');
      expect(ParcelOrder.fromJson(sample(status: 'cancelled')).statusLabel,
          'Cancelled');
    });

    test('handles missing rider and string decimals', () {
      final json = sample()..remove('rider');
      json['rider_id'] = null;
      json['distance_km'] = '5.4'; // Laravel DECIMAL arrives as string
      final o = ParcelOrder.fromJson(json);
      expect(o.riderName, isNull);
      expect(o.riderPhone, isNull);
      expect(o.distanceKm, 5.4);
    });
  });
}
