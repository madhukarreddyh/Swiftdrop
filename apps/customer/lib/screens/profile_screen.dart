import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/session.dart';
import '../theme.dart';
import '../utils/money.dart';
import 'login_screen.dart';
import 'support_screen.dart';

/// Profile, SOS, support, and logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _callSos(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Emergency SOS'),
        content: const Text(
            'This will dial 112, the national emergency helpline. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Call 112',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true) return;
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final session = context.read<SessionState>();
    await session.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionState>().user;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFE8F8F0),
                  child: Icon(Icons.person,
                      color: AppColors.primary, size: 32),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? 'SwiftDrop User',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 18)),
                      if (user != null)
                        Text(maskPhone(user.phone),
                            style:
                                const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _tile(
            context,
            icon: Icons.sos,
            color: AppColors.danger,
            title: 'Emergency SOS',
            subtitle: 'Call 112 in an emergency',
            onTap: () => _callSos(context),
          ),
          _tile(
            context,
            icon: Icons.support_agent,
            color: AppColors.primary,
            title: 'Help & Support',
            subtitle: 'Raise a ticket, we respond fast',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SupportScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.info_outline,
            color: AppColors.muted,
            title: 'About SwiftDrop',
            subtitle: 'Parcel delivery for Hyderabad · v0.1.0',
            onTap: () => showDialog(
              context: context,
              builder: (_) => const AlertDialog(
                title: Text('SwiftDrop'),
                content: Text(
                    'Fast, affordable parcel delivery across Hyderabad.\n\nBase fare ₹30 for the first 3 km, then ₹10 per km.'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _logout(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDecoration(),
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
        onTap: onTap,
      ),
    );
  }
}
