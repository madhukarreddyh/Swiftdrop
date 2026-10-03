import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/api_error.dart';
import '../models/order.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../utils/money.dart';
import '../widgets/otp_input.dart';
import 'delivered_screen.dart';

/// The active trip: pickup view (navigate + pickup OTP) → delivery view
/// (navigate + delivery OTP + collect payment).
class ActiveDeliveryScreen extends StatefulWidget {
  const ActiveDeliveryScreen({super.key, required this.order});

  final DeliveryOrder order;

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  late DeliveryOrder _order;
  final _otpKey = GlobalKey<OtpInputState>();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  bool get _atPickup => _order.isAssigned;

  Future<void> _openNavigation(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps.')),
      );
    }
  }

  Future<void> _submitOtp(String code) async {
    if (_busy || code.length != 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final updated = _atPickup
          ? await api.pickupOrder(_order.id, code)
          : await api.deliverOrder(_order.id, code);
      if (!mounted) return;
      if (updated.isDelivered) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => DeliveredScreen(order: updated),
          ),
        );
        return;
      }
      setState(() {
        _order = updated;
        _busy = false;
      });
      _otpKey.currentState?.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
      _otpKey.currentState?.clear();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach the server. Check your connection.';
        _busy = false;
      });
      _otpKey.currentState?.clear();
    }
  }

  void _reportWrongParcel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report wrong parcel'),
        content: const Text(
          'If the parcel is much bigger or heavier than described, '
          'tell the customer you need to cancel this delivery from '
          'your end and contact SwiftDrop support. The fare will be '
          'corrected on re-booking.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destLat = _atPickup ? _order.pickupLat : _order.dropLat;
    final destLng = _atPickup ? _order.pickupLng : _order.dropLng;
    return Scaffold(
      appBar: AppBar(
        title: Text(_order.displayId),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _stepHeader(),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _atPickup ? 'PICKUP PARCEL' : 'DELIVER PARCEL',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _atPickup ? _order.pickupAddress : _order.dropAddress,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  if (_order.parcelType != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Parcel: ${_order.parcelType}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _openNavigation(destLat, destLng),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _atPickup
                        ? 'Ask the customer for the pickup OTP'
                        : 'Ask the customer for the delivery OTP',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OtpInput(
                    key: _otpKey,
                    onCompleted: _submitOtp,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!_atPickup) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Collect from customer',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    Text(
                      '${formatPaise(_order.farePaise)} · ${_order.paymentMode == 'cash' ? 'Cash' : 'UPI'}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _reportWrongParcel,
                child: const Text('Report wrong parcel size'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepHeader() {
    return Row(
      children: [
        _step(1, 'Accepted', true),
        _line(true),
        _step(2, 'Picked up', !_atPickup),
        _line(!_atPickup),
        _step(3, 'Delivered', false),
      ],
    );
  }

  Widget _step(int n, String label, bool done) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: done ? AppColors.primary : AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '$n',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.muted),
        ),
      ],
    );
  }

  Widget _line(bool done) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
        color: done ? AppColors.primary : AppColors.border,
      ),
    );
  }
}
