import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_error.dart';
import '../models/order.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/money.dart';
import 'tracking_screen.dart';

/// Past and active orders for the logged-in customer.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<ParcelOrder>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiClient>();
      final orders = await api.getMyOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
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

  @override
  Widget build(BuildContext context) {
    final orders = _orders;
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: orders == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppColors.danger)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: _load,
                              child: const Text('Retry')),
                        ],
                      ),
                    )
                  : const CircularProgressIndicator(),
            )
          : orders.isEmpty
              ? const Center(
                  child: Text('No orders yet.\nBook your first parcel!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, fontSize: 16)),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _orderCard(orders[i]),
                  ),
                ),
    );
  }

  Widget _orderCard(ParcelOrder order) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context)
          .push(
            MaterialPageRoute(
                builder: (_) => TrackingScreen(orderId: order.id)),
          )
          .then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.displayId,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                _statusPill(order),
              ],
            ),
            const SizedBox(height: 8),
            Text(order.pickupAddress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
            const Text('↓',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
            Text(order.dropAddress,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              '${formatPaise(order.farePaise)} · ${order.distanceKm.toStringAsFixed(1)} km',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusPill(ParcelOrder order) {
    final Color bg;
    if (order.isDelivered) {
      bg = const Color(0xFFE8F8F0);
    } else if (order.isCancelled) {
      bg = const Color(0xFFFDECEC);
    } else {
      bg = const Color(0xFFFFF7E6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(order.statusLabel,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
