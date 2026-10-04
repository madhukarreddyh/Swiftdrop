import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../models/api_error.dart';
import '../models/order.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/money.dart';

/// Live order tracking: status timeline, pickup/drop map,
/// assigned rider card, cancel, and handover-OTP refresh.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key, required this.orderId});

  final int orderId;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  ParcelOrder? _order;
  String? _error;
  String? _devOtp;
  bool _cancelling = false;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _load();
    _poller = Timer.periodic(AppConfig.trackingPollInterval, (_) => _load());
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiClient>();
      final order = await api.getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401) {
        await context.read<SessionState>().handleAuthError(e);
        return;
      }
      setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Could not reach the server. Check your connection.');
      }
    }
  }

  Future<void> _cancel() async {
    final api = context.read<ApiClient>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('The rider will be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel order')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _cancelling = true);
    try {
      final order = await api.cancelOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _refreshOtp() async {
    try {
      final api = context.read<ApiClient>();
      final res = await api.refreshOrderOtp(widget.orderId);
      if (!mounted) return;
      setState(() => _devOtp = res['dev_otp'] as String?);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New OTP generated.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _callRider(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      appBar: AppBar(
        title: Text(order == null ? 'Tracking' : order.displayId),
      ),
      body: order == null
          ? Center(
              child: _error != null
                  ? Text(_error!,
                      style: const TextStyle(color: AppColors.danger))
                  : const CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _statusBanner(order),
                  const SizedBox(height: 16),
                  _miniMap(order),
                  const SizedBox(height: 16),
                  _timeline(order),
                  if (order.riderId != null) ...[
                    const SizedBox(height: 16),
                    _riderCard(order),
                  ],
                  if (_devOtp != null) ...[
                    const SizedBox(height: 16),
                    _otpBanner(),
                  ],
                  const SizedBox(height: 16),
                  _addressCard(order),
                  const SizedBox(height: 24),
                  if (order.isRequested || order.isAssigned)
                    OutlinedButton(
                      onPressed: _cancelling ? null : _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: _cancelling
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Cancel order'),
                    ),
                  if (order.isAssigned || order.isPickedUp)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed: _refreshOtp,
                        child: const Text('Generate new handover OTP'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _statusBanner(ParcelOrder order) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping,
              color: AppColors.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.statusLabel,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                Text(
                  '${formatPaise(order.farePaise)} · ${order.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMap(ParcelOrder order) {
    final pickup = LatLng(order.pickupLat, order.pickupLng);
    final drop = LatLng(order.dropLat, order.dropLng);
    final center = LatLng(
      (pickup.latitude + drop.latitude) / 2,
      (pickup.longitude + drop.longitude) / 2,
    );
    return SizedBox(
      height: 180,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.swiftdrop.swiftdrop_customer',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: pickup,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on,
                      color: AppColors.primary, size: 40),
                ),
                Marker(
                  point: drop,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on,
                      color: AppColors.danger, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeline(ParcelOrder order) {
    final steps = [
      ('Order placed', true),
      ('Rider assigned', order.isAssigned || order.isPickedUp || order.isDelivered),
      ('Picked up', order.isPickedUp || order.isDelivered),
      ('Delivered', order.isDelivered),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        children: steps.asMap().entries.map((e) {
          final i = e.key;
          final done = e.value.$2;
          final last = i == steps.length - 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? AppColors.primary : AppColors.border,
                    ),
                    child: done
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                  if (!last)
                    Container(width: 2, height: 24, color: AppColors.border),
                ],
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  e.value.$1,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: done ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _riderCard(ParcelOrder order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: Color(0xFFE8F8F0),
            child: Icon(Icons.person, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.riderName ?? 'Your rider',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                if (order.riderPhone != null)
                  Text(maskPhone(order.riderPhone),
                      style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          if (order.riderPhone != null)
            IconButton(
              icon: const Icon(Icons.call, color: AppColors.primary),
              onPressed: () => _callRider(order.riderPhone!),
              tooltip: 'Call rider',
            ),
        ],
      ),
    );
  }

  Widget _otpBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning),
      ),
      child: Text(
        'Test mode — handover OTP: $_devOtp\nShare it with the rider at handover.',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _addressCard(ParcelOrder order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        children: [
          _addrRow(Icons.my_location, AppColors.primary, 'Pickup',
              order.pickupAddress),
          const Divider(height: 20),
          _addrRow(Icons.location_on, AppColors.danger, 'Drop',
              order.dropAddress),
          if (order.parcelType != null) ...[
            const Divider(height: 20),
            _addrRow(Icons.inventory_2, AppColors.muted, 'Parcel',
                order.parcelType!),
          ],
        ],
      ),
    );
  }

  Widget _addrRow(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12)),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
