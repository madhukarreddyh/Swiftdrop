import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/api_error.dart';
import '../models/order.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../services/offer_poller.dart';
import '../services/session.dart';
import '../theme.dart';
import '../utils/money.dart';
import 'earnings_screen.dart';
import 'incoming_order_screen.dart';
import 'profile_screen.dart';

/// Main screen: bottom tabs (Home / Earnings / Profile).
/// Home tab handles offline/online state, the map, and incoming offers.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _online = false;
  bool _busy = false;
  Position? _position;
  int _todayPaise = 0;
  int _todayTrips = 0;

  late final OfferPoller _poller;
  late final LocationService _location;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _poller = OfferPoller(api);
    _location = LocationService(api);
    _poller.onNewOffer = _onNewOffer;
    _poller.onError = (e) {
      if (e is ApiException && e.statusCode == 401 && mounted) {
        context.read<SessionState>().logout();
      }
    };
    _online = context.read<SessionState>().profile?.isOnline ?? false;
    _loadToday();
    if (_online) _goOnline(silent: true);
  }

  @override
  void dispose() {
    _poller.stop();
    _location.stopPinging();
    super.dispose();
  }

  Future<void> _loadToday() async {
    try {
      final earnings = await context.read<ApiClient>().getEarnings();
      if (!mounted) return;
      setState(() {
        _todayPaise = earnings.todayPaise;
        _todayTrips = earnings.totalTrips;
      });
    } catch (_) {
      // Ticker is best-effort; the Earnings tab shows full data.
    }
  }

  Future<void> _goOnline({bool silent = false}) async {
    final api = context.read<ApiClient>();
    final session = context.read<SessionState>();
    setState(() => _busy = true);
    try {
      final pos = await _location.currentPosition();
      if (!silent && pos == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is needed to go online.',
            ),
          ),
        );
        setState(() => _busy = false);
        return;
      }
      if (pos != null) {
        setState(() => _position = pos);
      }
      final profile = await api.setOnline(
        true,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );
      if (!mounted) return;
      setState(() {
        _online = profile.isOnline;
        _busy = false;
      });
      _location.startPinging();
      _poller.resume();
      _poller.start();
      await session.refreshProfile();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not go online. Check your connection.'),
        ),
      );
    }
  }

  Future<void> _goOffline() async {
    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().setOnline(false);
    } catch (_) {
      // Best effort — still stop locally.
    }
    _poller.stop();
    _location.stopPinging();
    if (!mounted) return;
    setState(() {
      _online = false;
      _busy = false;
    });
    await context.read<SessionState>().refreshProfile();
  }

  void _onNewOffer(DeliveryOrder offer) {
    if (!mounted) return;
    _poller.pause();
    Navigator.of(context)
        .push<DeliveryOrder?>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingOrderScreen(offer: offer),
      ),
    )
        .then((accepted) {
      // Card dismissed (accepted, declined, timed out, or taken).
      if (!mounted) return;
      if (accepted != null) {
        // Accepted orders are handled inside IncomingOrderScreen.
        return;
      }
      _poller.resume();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _buildHomeTab(),
      const EarningsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: tabs[_tab],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet),
            label: 'Earnings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return Stack(
      children: [
        _buildMap(dimmed: !_online),
        SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const Spacer(),
              _buildBottomPanel(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMap({required bool dimmed}) {
    final center = _position != null
        ? LatLng(_position!.latitude, _position!.longitude)
        : const LatLng(17.3850, 78.4867); // Hyderabad fallback
    return ColorFiltered(
      colorFilter: dimmed
          ? const ColorFilter.mode(Colors.black54, BlendMode.darken)
          : const ColorFilter.mode(
              Colors.transparent,
              BlendMode.multiply,
            ),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 14,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'app.swiftdrop.rider',
          ),
          if (_position != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(
                    _position!.latitude,
                    _position!.longitude,
                  ),
                  width: 48,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.two_wheeler,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: cardDecoration(),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _online ? "You're online" : 'Hello, partner',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          _online
                              ? 'Waiting for orders near you'
                              : 'Go online to start earning',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_online)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stat("Today's earnings", formatPaise(_todayPaise)),
              _stat('Trips', '$_todayTrips'),
              _stat(
                'Rating',
                '${(context.watch<SessionState>().profile?.rating ?? 0).toStringAsFixed(1)}★',
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _busy
                ? null
                : (_online ? _goOffline : () => _goOnline()),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _online ? AppColors.ink : AppColors.primary,
            ),
            child: _busy
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(_online ? 'Go Offline' : 'Go Online'),
          ),
          if (!_online) ...[
            const SizedBox(height: 12),
            const Text(
              'You will receive order requests only while online.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}
