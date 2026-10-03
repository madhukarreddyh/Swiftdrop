import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_error.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../theme.dart';
import '../widgets/otp_input.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'verification_pending_screen.dart';

/// Verifies the 4-digit OTP. On success routes by account state.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone, this.devCode});

  final String phone;

  /// In dev (APP_DEBUG=true) the backend returns the code in the response.
  final String? devCode;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otpKey = GlobalKey<OtpInputState>();
  bool _busy = false;
  String? _error;
  int _resendIn = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn > 0) {
        setState(() => _resendIn--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify(String code) async {
    if (_busy || code.length != 4) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      final session = context.read<SessionState>();
      final result = await api.verifyOtp(widget.phone, code);
      await session.afterLogin(result.user);
      if (!mounted) return;
      switch (session.status) {
        case SessionStatus.ready:
          _replace(const HomeScreen());
          break;
        case SessionStatus.needsOnboarding:
          _replace(const OnboardingScreen());
          break;
        case SessionStatus.pendingVerification:
        case SessionStatus.rejected:
          _replace(const VerificationPendingScreen());
          break;
        case SessionStatus.loggedOut:
        case SessionStatus.error:
        case SessionStatus.unknown:
          setState(() => _error = 'Login failed. Please try again.');
          break;
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
      _otpKey.currentState?.clear();
    } catch (_) {
      setState(
        () => _error = 'Could not reach the server. Check your connection.',
      );
      _otpKey.currentState?.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _replace(Widget screen) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen),
      (_) => false,
    );
  }

  Future<void> _resend() async {
    setState(() {
      _resendIn = 30;
      _error = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn > 0) {
        if (mounted) setState(() => _resendIn--);
      } else {
        t.cancel();
      }
    });
    try {
      await context.read<ApiClient>().sendOtp(widget.phone);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not resend. Check your connection.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Enter OTP',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sent to +91 ${widget.phone}',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 32),
              OtpInput(
                key: _otpKey,
                onCompleted: _verify,
              ),
              if (widget.devCode != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Dev mode: your OTP is ${widget.devCode}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
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
              const SizedBox(height: 24),
              if (_busy)
                const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                )
              else if (_resendIn > 0)
                Center(
                  child: Text(
                    'Resend OTP in $_resendIn s',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                )
              else
                Center(
                  child: TextButton(
                    onPressed: _resend,
                    child: const Text('Resend OTP'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
