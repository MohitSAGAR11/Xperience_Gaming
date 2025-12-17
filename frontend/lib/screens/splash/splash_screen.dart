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
    // Wait for animation to complete
    await Future.delayed(const Duration(seconds: 2));

    // Initialize auth state (but don't wait for it to complete)
    // This allows the splash screen to show briefly then navigate
    ref.read(authProvider.notifier).initialize();

    if (!mounted) return;

    // Navigate immediately - don't wait for auth initialization
    // The auth screen will handle showing loading state if needed
    final authState = ref.read(authProvider);
    
    if (authState.isAuthenticated) {
      // User is logged in
      if (authState.isOwner) {
        context.go(Routes.ownerDashboard);
      } else {
        context.go(Routes.clientHome);
      }
    } else {
      // User is not logged in - go to auth screen
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
        decoration: const BoxDecoration(
          color: AppColors.trueBlack,
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
                      // Logo Container with Sharp Border
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.neonPurple.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Image.asset(
                          'assets/icons/splash_screen.png',
                          width: 160,
                          height: 160,
                          fit: BoxFit.contain,
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

