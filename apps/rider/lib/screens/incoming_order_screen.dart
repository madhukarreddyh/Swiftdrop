import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/api_error.dart';
import '../models/order.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/countdown_ring.dart';
import 'active_delivery_screen.dart';

/// Full-screen incoming-order card.
/// Returns the accepted [DeliveryOrder] on success, null otherwise.
class IncomingOrderScreen extends StatefulWidget {
  const IncomingOrderScreen({super.key, required this.offer});

  final DeliveryOrder offer;

  @override
  State<IncomingOrderScreen> createState() => _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends State<IncomingOrderScreen> {
  bool _busy = false;
  bool _timedOut = false;

  Future<void> _accept() async {
    if (_busy || _timedOut) return;
    setState(() => _busy = true);
    try {
      final order = await context
          .read<ApiClient>()
          .acceptOrder(widget.offer.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveDeliveryScreen(order: order),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final taken = e.code == 'ALREADY_TAKEN';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            taken
                ? 'Order taken by another partner.'
                : e.message,
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not accept. Check your connection.'),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _decline() => Navigator.of(context).pop();

  void _onTimeout() {
    if (!mounted || _busy) return;
    setState(() => _timedOut = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Offer expired.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.offer;
    return Scaffold(
      backgroundColor: AppColors.ink.withValues(alpha: 0.55),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New delivery request',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      CountdownRing(
                        duration: AppConfig.offerCountdown,
                        onTimeout: _onTimeout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    o.displayId,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _routeRow(
                    Icons.my_location,
                    AppColors.primary,
                    'PICKUP',
                    o.pickupAddress,
                  ),
                  _timelineConnector(),
                  _routeRow(
                    Icons.location_on,
                    AppColors.danger,
                    'DROP',
                    o.dropAddress,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${o.distanceKm.toStringAsFixed(1)} km'
                          '${o.parcelType != null ? ' · ${o.parcelType}' : ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.muted,
                          ),
                        ),
                        Text(
                          'Fare ${formatPaise(o.farePaise)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color:
                          AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'YOU EARN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatPaise(o.riderEarningPaise),
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _decline,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: const BorderSide(
                              color: AppColors.border,
                            ),
                            foregroundColor: AppColors.ink,
                          ),
                          child: const Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _accept,
                          child: _busy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('ACCEPT'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _routeRow(
    IconData icon,
    Color color,
    String label,
    String address,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _timelineConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            width: 2,
            height: 6,
            margin: const EdgeInsets.symmetric(vertical: 1),
            color: AppColors.border,
          ),
        ),
      ),
    );
  }
}
