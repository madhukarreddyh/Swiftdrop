import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/api_error.dart';
import '../models/fare_quote.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../utils/money.dart';
import 'tracking_screen.dart';

/// Map-first booking flow (Rapido-style):
/// type pickup/drop addresses, tap the map to place pins,
/// get a server-computed fare, then book.
class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

enum _PinMode { pickup, drop }

class _BookingScreenState extends State<BookingScreen> {
  static const _hyderabad = LatLng(17.3850, 78.4867);

  final _mapCtrl = MapController();
  final _pickupCtrl = TextEditingController();
  final _dropCtrl = TextEditingController();

  _PinMode _mode = _PinMode.pickup;
  LatLng? _pickup;
  LatLng? _drop;
  String _parcelType = 'Documents';
  String _paymentMode = 'upi';

  FareQuote? _quote;
  bool _quoting = false;
  bool _booking = false;
  String? _error;

  static const _parcelTypes = [
    'Documents',
    'Food',
    'Groceries',
    'Medicines',
    'Electronics',
    'Clothes',
    'Other',
  ];

  @override
  void dispose() {
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _mapCtrl.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() => _error = null);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _error = 'Location permission is needed for pickup.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _pickup = ll;
        if (_pickupCtrl.text.isEmpty) {
          _pickupCtrl.text = 'My location';
        }
        _quote = null;
      });
      _mapCtrl.move(ll, 15);
    } catch (_) {
      setState(() => _error = 'Could not get your location.');
    }
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      if (_mode == _PinMode.pickup) {
        _pickup = point;
      } else {
        _drop = point;
      }
      _quote = null;
      _error = null;
    });
  }

  bool get _canQuote =>
      _pickup != null &&
      _drop != null &&
      _pickupCtrl.text.trim().isNotEmpty &&
      _dropCtrl.text.trim().isNotEmpty;

  Future<void> _getFare() async {
    if (!_canQuote) {
      setState(() => _error =
          'Enter both addresses and place both pins on the map.');
      return;
    }
    setState(() {
      _quoting = true;
      _error = null;
      _quote = null;
    });
    try {
      final api = context.read<ApiClient>();
      final q = await api.getFareQuote(
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        dropLat: _drop!.latitude,
        dropLng: _drop!.longitude,
      );
      setState(() => _quote = q);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
          () => _error = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _book() async {
    if (_quote == null) return;
    setState(() {
      _booking = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final order = await api.createOrder(
        pickupAddress: _pickupCtrl.text.trim(),
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        dropAddress: _dropCtrl.text.trim(),
        dropLat: _drop!.latitude,
        dropLng: _drop!.longitude,
        parcelType: _parcelType,
        paymentMode: _paymentMode,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrackingScreen(orderId: order.id),
        ),
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
          () => _error = 'Could not reach the server. Check your connection.');
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _hyderabad,
              initialZoom: 12,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.swiftdrop.swiftdrop_customer',
              ),
              MarkerLayer(
                markers: [
                  if (_pickup != null)
                    Marker(
                      point: _pickup!,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.location_on,
                          color: AppColors.primary, size: 44),
                    ),
                  if (_drop != null)
                    Marker(
                      point: _drop!,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.location_on,
                          color: AppColors.danger, size: 44),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _modeToggle(),
                ],
              ),
            ),
          ),
          _bottomSheet(),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 8),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeChip('Pickup pin', _PinMode.pickup, AppColors.primary),
          _modeChip('Drop pin', _PinMode.drop, AppColors.danger),
        ],
      ),
    );
  }

  Widget _modeChip(String label, _PinMode mode, Color color) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _bottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.52,
      minChildSize: 0.32,
      maxChildSize: 0.92,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(color: Color(0x22000000), blurRadius: 16),
            ],
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Send a parcel',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pickupCtrl,
                decoration: InputDecoration(
                  hintText: 'Pickup address',
                  prefixIcon: const Icon(Icons.my_location,
                      color: AppColors.primary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.gps_fixed),
                    tooltip: 'Use my location',
                    onPressed: _useMyLocation,
                  ),
                ),
                onChanged: (_) => setState(() => _quote = null),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _dropCtrl,
                decoration: const InputDecoration(
                  hintText: 'Drop address',
                  prefixIcon:
                      Icon(Icons.location_on, color: AppColors.danger),
                ),
                onChanged: (_) => setState(() => _quote = null),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the map to place the pickup (green) and drop (red) pins.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text("What's inside?",
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _parcelTypes.map((t) {
                  final sel = _parcelType == t;
                  return ChoiceChip(
                    label: Text(t),
                    selected: sel,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        color: sel ? Colors.white : AppColors.ink),
                    onSelected: (_) => setState(() => _parcelType = t),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Pay via',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('UPI'),
                    selected: _paymentMode == 'upi',
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        color: _paymentMode == 'upi'
                            ? Colors.white
                            : AppColors.ink),
                    onSelected: (_) =>
                        setState(() => _paymentMode = 'upi'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Cash'),
                    selected: _paymentMode == 'cash',
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                        color: _paymentMode == 'cash'
                            ? Colors.white
                            : AppColors.ink),
                    onSelected: (_) =>
                        setState(() => _paymentMode = 'cash'),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 12),
              if (_quote == null)
                ElevatedButton(
                  onPressed: _quoting ? null : _getFare,
                  child: _quoting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('See fare'),
                )
              else ...[
                _fareCard(_quote!),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _booking ? null : _book,
                  child: _booking
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text('Book parcel · ${formatPaise(_quote!.farePaise)}'),
                ),
                TextButton(
                  onPressed: () => setState(() => _quote = null),
                  child: const Text('Change details'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _fareCard(FareQuote q) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${q.distanceKm.toStringAsFixed(1)} km',
                style: const TextStyle(color: AppColors.muted),
              ),
              Text(
                formatPaise(q.farePaise),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Divider(height: 20),
          ...q.breakdown.map(
            (l) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: Text(l.label,
                          style: const TextStyle(fontSize: 13))),
                  Text(formatPaise(l.amountPaise),
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
