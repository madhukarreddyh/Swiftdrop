import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swiftdrop_rider/models/order.dart';
import 'package:swiftdrop_rider/screens/incoming_order_screen.dart';
import 'package:swiftdrop_rider/services/api_client.dart';

DeliveryOrder _sampleOffer() {
  return DeliveryOrder(
    id: 42,
    pickupAddress: 'Flat 402, KPHB Colony Phase 3',
    pickupLat: 17.4833,
    pickupLng: 78.3915,
    dropAddress: 'Moosapet Metro Station',
    dropLat: 17.4666,
    dropLng: 78.3980,
    distanceKm: 4.2,
    farePaise: 5000,
    platformFeePaise: 250,
    riderEarningPaise: 4750,
    parcelType: 'Documents',
    status: 'requested',
    paymentMode: 'upi',
  );
}

void main() {
  testWidgets('incoming order card shows route and earning',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Provider<ApiClient>(
          create: (_) => ApiClient(),
          child: IncomingOrderScreen(offer: _sampleOffer()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('New delivery request'), findsOneWidget);
    expect(find.text('Flat 402, KPHB Colony Phase 3'), findsOneWidget);
    expect(find.text('Moosapet Metro Station'), findsOneWidget);
    // 4750 paise = ₹47.50
    expect(find.text('₹47.50'), findsOneWidget);
    expect(find.text('ACCEPT'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
  });

  testWidgets('order model parses backend JSON', (tester) async {
    final order = DeliveryOrder.fromJson({
      'id': 7,
      'pickup_address': 'A',
      'pickup_lat': 17.4,
      'pickup_lng': 78.4,
      'drop_address': 'B',
      'drop_lat': 17.5,
      'drop_lng': 78.5,
      'distance_km': 5.0,
      'fare_paise': 5000,
      'platform_fee_paise': 250,
      'rider_earning_paise': 4750,
      'status': 'assigned',
      'customer': {'name': 'Aditya', 'phone': '919999999999'},
    });

    expect(order.id, 7);
    expect(order.riderEarningPaise, 4750);
    expect(order.isAssigned, isTrue);
    expect(order.displayId, 'SD-10007');
    expect(order.customerName, 'Aditya');
  });
}
