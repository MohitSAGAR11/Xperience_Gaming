import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../config/theme.dart';

/// Upcoming Features Screen - Shows planned features
class UpcomingFeaturesScreen extends StatelessWidget {
  const UpcomingFeaturesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.rocket_launch, color: AppColors.cyberCyan),
            const SizedBox(width: 8),
            const Text(
              'Upcoming Features',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.neonPurple.withOpacity(0.2),
                    AppColors.cyberCyan.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.neonPurple.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.rocket_launch,
                    size: 64,
                    color: AppColors.cyberCyan,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Exciting Features Coming Soon!',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'re constantly working on new features to enhance your gaming experience',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Features List
            const Text(
              'Planned Features',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _FeatureCard(
              icon: Iconsax.game,
              title: 'Console Gaming Support',
              description: 'Book PlayStation, Xbox, and Nintendo Switch consoles',
              status: 'In Development',
              color: AppColors.neonPurple,
            ),
            const SizedBox(height: 12),

            _FeatureCard(
              icon: Iconsax.message,
              title: 'In-App Chat',
              description: 'Chat with cafe owners and other gamers',
              status: 'Coming Soon',
              color: AppColors.cyberCyan,
            ),
            const SizedBox(height: 12),

            _FeatureCard(
              icon: Iconsax.star,
              title: 'Loyalty Rewards',
              description: 'Earn points and unlock exclusive rewards',
              status: 'Planned',
              color: AppColors.warning,
            ),
            const SizedBox(height: 12),

            _FeatureCard(
              icon: Iconsax.notification,
              title: 'Smart Notifications',
              description: 'Get notified about special offers and events',
              status: 'Planned',
              color: AppColors.success,
            ),
            const SizedBox(height: 12),

            _FeatureCard(
              icon: Iconsax.chart,
              title: 'Advanced Analytics',
              description: 'Track your gaming stats and achievements',
              status: 'Planned',
              color: AppColors.error,
            ),
            const SizedBox(height: 12),

            _FeatureCard(
              icon: Iconsax.people,
              title: 'Social Features',
              description: 'Connect with friends and form gaming groups',
              status: 'Planned',
              color: AppColors.neonPurple,
            ),
            const SizedBox(height: 32),

            // Feedback Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.cardDark,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Iconsax.message_question,
                    size: 40,
                    color: AppColors.cyberCyan,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Have a Feature Request?',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'d love to hear your ideas! Share your suggestions through the Help & Support section.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String status;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

