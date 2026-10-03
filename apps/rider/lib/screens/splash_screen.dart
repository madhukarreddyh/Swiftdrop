import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'verification_pending_screen.dart';

/// Entry screen: shows the brand, restores the session, then routes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final session = context.read<SessionState>();
    // Let the splash breathe for a moment.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await session.restore();
    if (!mounted) return;
    switch (session.status) {
      case SessionStatus.ready:
        _go(const HomeScreen());
        break;
      case SessionStatus.needsOnboarding:
        _go(const OnboardingScreen());
        break;
      case SessionStatus.pendingVerification:
      case SessionStatus.rejected:
        _go(const VerificationPendingScreen());
        break;
      case SessionStatus.loggedOut:
      case SessionStatus.error:
      case SessionStatus.unknown:
        _go(const LoginScreen());
        break;
    }
  }

  void _go(Widget screen) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SwiftDropLogo(size: 110),
              const SizedBox(height: 24),
              const Text(
                'SwiftDrop',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'PARTNER',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Earn on your schedule',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
