import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/session.dart';
import '../theme.dart';
import '../widgets/logo.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';

/// Shown after applying, while the admin verifies documents.
/// Pull to refresh — routes to Home once approved.
class VerificationPendingScreen extends StatelessWidget {
  const VerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final rejected = session.status == SessionStatus.rejected;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await session.refreshProfile();
          },
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              const SizedBox(height: 48),
              Center(
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: rejected
                        ? AppColors.danger.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    rejected
                        ? Icons.error_outline
                        : Icons.hourglass_top_rounded,
                    size: 52,
                    color: rejected
                        ? AppColors.danger
                        : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                rejected ? 'Verification failed' : 'Verification pending',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                rejected
                    ? 'Your documents could not be verified. '
                        'Please check the details and apply again.'
                    : 'We are verifying your documents.\n'
                        'This usually takes under 24 hours.\n'
                        'Pull down to check status.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (rejected)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const OnboardingScreen(),
                      ),
                    );
                  },
                  child: const Text('Apply again'),
                ),
              if (session.status == SessionStatus.ready)
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const HomeScreen(),
                      ),
                      (_) => false,
                    );
                  },
                  child: const Text('Start earning'),
                ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => session.logout(),
                  child: const Text('Log out'),
                ),
              ),
              const SizedBox(height: 24),
              const Center(child: SwiftDropLogo(size: 40)),
            ],
          ),
        ),
      ),
    );
  }
}
