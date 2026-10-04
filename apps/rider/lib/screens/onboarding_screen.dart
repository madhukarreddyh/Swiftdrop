import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_error.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import 'verification_pending_screen.dart';

/// Partner application: collects KYC documents plus vehicle type and submits
/// them via POST /rider/apply, which flips the account to role=rider (pending).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _aadhaar = TextEditingController();
  final _licence = TextEditingController();
  final _rc = TextEditingController();
  final _bikeNumber = TextEditingController();
  final _bank = TextEditingController();
  String _vehicleType = 'bike'; // 'bike' | 'auto'
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _aadhaar.dispose();
    _licence.dispose();
    _rc.dispose();
    _bikeNumber.dispose();
    _bank.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _aadhaar.text.trim().isNotEmpty &&
      _licence.text.trim().isNotEmpty &&
      _rc.text.trim().isNotEmpty &&
      _bikeNumber.text.trim().isNotEmpty &&
      _bank.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_valid) {
      setState(
        () => _error = 'Please fill in all documents to continue.',
      );
      return;
    }
    final api = context.read<ApiClient>();
    final session = context.read<SessionState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.applyAsRider(
        name: _name.text.trim(),
        aadhaar: _aadhaar.text.trim(),
        licenceNo: _licence.text.trim(),
        bikeRc: _rc.text.trim(),
        bikeNumber: _bikeNumber.text.trim().toUpperCase(),
        bankAccount: _bank.text.trim(),
        vehicleType: _vehicleType,
      );
      await session.refreshProfile();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const VerificationPendingScreen(),
        ),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(
        () => _error = 'Could not reach the server. Check your connection.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleLabel = _vehicleType == 'bike' ? 'Bike' : 'Auto';
    return Scaffold(
      appBar: AppBar(title: const Text('Become a partner')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Center(child: SwiftDropLogo(size: 56)),
            const SizedBox(height: 16),
            const Text(
              'Your documents',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We verify every partner before the first trip. '
              'Approval usually takes under 24 hours.',
              style: TextStyle(fontSize: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            _field(_name, 'Full name', 'Ravi Kumar'),
            _field(_aadhaar, 'Aadhaar number', '1234 5678 9012',
                numeric: true),
            _field(_licence, 'Driving licence number', 'TS09 20210012345'),
            _vehicleSelector(),
            _field(_rc, '$vehicleLabel RC number', 'TS09AB1234'),
            _field(
                _bikeNumber, '$vehicleLabel number plate', 'TS 09 AB 1234'),
            _field(_bank, 'Bank account number', '50100234567891',
                numeric: true),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit for verification'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () =>
                  context.read<SessionState>().logout(),
              child: const Text('Log out'),
            ),
          ],
        ),
      ),
    );
  }

  /// Bike / Auto selector. Defaults to Bike.
  Widget _vehicleSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vehicle type',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _vehicleChip('bike', 'Bike', Icons.two_wheeler),
              const SizedBox(width: 12),
              _vehicleChip('auto', 'Auto', Icons.local_taxi),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vehicleChip(String value, String label, IconData icon) {
    final selected = _vehicleType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _vehicleType = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : const Color(0xFFD1D5DB),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.white : AppColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    bool numeric = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType:
                numeric ? TextInputType.number : TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(hintText: hint),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
