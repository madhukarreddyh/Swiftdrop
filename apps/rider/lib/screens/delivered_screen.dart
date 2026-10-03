import 'package:flutter/material.dart';

import '../models/order.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/logo.dart';
import 'home_screen.dart';

/// Celebration after a successful delivery.
class DeliveredScreen extends StatelessWidget {
  const DeliveredScreen({super.key, required this.order});

  final DeliveryOrder order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 58,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '${formatPaise(order.riderEarningPaise)} earned!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Delivery complete. Great work, partner!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: cardDecoration(),
                child: Column(
                  children: [
                    _row('Order', order.displayId),
                    _row('Route',
                        '${order.pickupAddress} → ${order.dropAddress}'),
                    _row(
                        'Distance',
                        '${order.distanceKm.toStringAsFixed(1)} km'),
                    _row('Customer fare',
                        formatPaise(order.farePaise)),
                    _row('Your earning',
                        formatPaise(order.riderEarningPaise),
                        highlight: true),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const HomeScreen(),
                    ),
                    (_) => false,
                  );
                },
                child: const Text('Back to Home'),
              ),
              const SizedBox(height: 20),
              const Center(child: SwiftDropLogo(size: 36)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    highlight ? FontWeight.w800 : FontWeight.w600,
                color: highlight
                    ? AppColors.primary
                    : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
