import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/theme.dart';
import '../../../config/routes.dart';

/// Verification Pending Screen
/// Shown when owner tries to create a cafe but is not verified
class VerificationPendingScreen extends ConsumerWidget {
  const VerificationPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      appBar: AppBar(
        backgroundColor: AppColors.trueBlack,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.ownerDashboard),
        ),
        title: const Text('Verification Required'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.warning.withOpacity(0.1),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    size: 80,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Title
                Text(
                  'Verification Pending',
                  style: GoogleFonts.orbitron(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Message
                Text(
                  'You are not verified yet. Please wait for admin verification to access the features.',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Info Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.warning.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: AppColors.warning,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'What happens next?',
                              style: GoogleFonts.roboto(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your account is under review. Once verified by our admin team, you\'ll be able to create and manage cafes. You\'ll receive a notification once your verification is complete.',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Back Button
                ElevatedButton(
                  onPressed: () => context.go(Routes.ownerDashboard),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Go to Dashboard',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

