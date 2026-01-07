import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';
import '../../../providers/auth_provider.dart';
import '../../../widgets/custom_button.dart';
import '../../../core/utils.dart';

/// Owner Profile Screen
class OwnerProfileScreen extends ConsumerWidget {
  const OwnerProfileScreen({super.key});

  static void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text(
          'Delete Account',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.\n\n'
          'All your data including cafes, bookings, earnings, reviews, and profile information will be permanently deleted.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              
              // Show loading
              if (context.mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (loadingContext) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final success = await ref.read(authProvider.notifier).deleteAccount();
              
              // Close loading dialog first
              if (context.mounted) {
                Navigator.of(context).pop(); // Close loading
              }
              
              if (success) {
                // Get router from provider before any delays
                final router = ref.read(routerProvider);
                
                // Wait a moment to ensure state is cleared and dialogs are closed
                await Future.delayed(const Duration(milliseconds: 300));
                
                // Navigate directly to auth screen, replacing entire stack
                router.go(Routes.auth);
              } else {
                if (context.mounted) {
                  final error = ref.read(authProvider).error;
                  SnackbarUtils.showError(
                    context,
                    error ?? 'Failed to delete account. Please try again.',
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      appBar: AppBar(
        backgroundColor: AppColors.trueBlack,
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.cyberCyan,
              child: Text(
                user?.initials ?? 'O',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.trueBlack,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.name ?? 'Owner',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              user?.email ?? '',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.cyberCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Cafe Owner',
                style: TextStyle(
                  color: AppColors.cyberCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Menu Items
            _ProfileMenuItem(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: () => context.push(Routes.editOwnerProfile),
            ),
            _ProfileMenuItem(
              icon: Icons.store_outlined,
              title: 'My Cafes',
              onTap: () => context.go(Routes.myCafes),
            ),
            _ProfileMenuItem(
              icon: Icons.analytics_outlined,
              title: 'Analytics',
              onTap: () => context.push(Routes.earningsAnalytics),
            ),
            _ProfileMenuItem(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Earnings',
              onTap: () => context.push(Routes.earningsAnalytics),
            ),
            _ProfileMenuItem(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () => context.push(Routes.ownerHelpSupport),
            ),
            _ProfileMenuItem(
              icon: Icons.feedback_outlined,
              title: 'Feedback',
              onTap: () async {
                const feedbackUrl = 'https://forms.gle/fUGQP9TNX3tNX5SZ8';
                final uri = Uri.parse(feedbackUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    SnackbarUtils.showError(context, 'Could not open feedback form');
                  }
                }
              },
            ),
            const SizedBox(height: 32),

            // Delete Account Button
            CyberOutlineButton(
              text: 'Delete Account',
              icon: Icons.delete_forever_outlined,
              color: AppColors.error,
              onPressed: () => _showDeleteAccountDialog(context, ref),
            ),
            const SizedBox(height: 16),

            // Logout Button
            CyberOutlineButton(
              text: 'Logout',
              icon: Icons.logout,
              color: AppColors.error,
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go(Routes.auth);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(
          title,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}

