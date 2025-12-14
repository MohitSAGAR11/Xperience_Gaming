import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/auth_provider.dart';

/// Splash Screen - Initial loading screen with app logo
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait for animation
    await Future.delayed(const Duration(seconds: 2));

    // Initialize auth state
    await ref.read(authProvider.notifier).initialize();

    if (!mounted) return;

    // Navigate based on auth state
    final authState = ref.read(authProvider);

    if (authState.isAuthenticated) {
      // User is logged in
      if (authState.isOwner) {
        context.go(Routes.ownerDashboard);
      } else {
        context.go(Routes.clientHome);
      }
    } else {
      // User is not logged in
      context.go(Routes.auth);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.trueBlack,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              AppColors.neonPurple.withOpacity(0.15),
              AppColors.trueBlack,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo Container with Glow
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.neonPurple.withOpacity(0.5),
                              blurRadius: 60,
                              spreadRadius: 10,
                            ),
                            BoxShadow(
                              color: AppColors.cyberCyan.withOpacity(0.3),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.sports_esports,
                          size: 80,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // App Name
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.primaryGradient.createShader(bounds),
                        child: Text(
                          'XPERIENCE',
                          style: GoogleFonts.orbitron(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'GAMING',
                        style: GoogleFonts.orbitron(
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          color: AppColors.cyberCyan,
                          letterSpacing: 12,
                        ),
                      ),
                      const SizedBox(height: 48),
                      // Loading indicator
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.neonPurple.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

