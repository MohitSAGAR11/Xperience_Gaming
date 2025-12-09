import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';

/// Owner Main Screen - Shell with Bottom Navigation
class OwnerMainScreen extends StatelessWidget {
  final Widget child;

  const OwnerMainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const _OwnerBottomNav(),
    );
  }
}

class _OwnerBottomNav extends StatelessWidget {
  const _OwnerBottomNav();

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/owner/cafes')) return 1;
    if (location.startsWith('/owner/profile')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        boxShadow: [
          BoxShadow(
            color: AppColors.cyberCyan.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Iconsax.chart_square,
                activeIcon: Iconsax.chart_square5,
                label: 'Dashboard',
                isSelected: selectedIndex == 0,
                onTap: () => context.go(Routes.ownerDashboard),
              ),
              _NavItem(
                icon: Iconsax.shop,
                activeIcon: Iconsax.shop5,
                label: 'My Cafes',
                isSelected: selectedIndex == 1,
                onTap: () => context.go(Routes.myCafes),
              ),
              _NavItem(
                icon: Iconsax.user,
                activeIcon: Iconsax.user,
                label: 'Profile',
                isSelected: selectedIndex == 2,
                onTap: () => context.go(Routes.ownerProfile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.cyberCyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.cyberCyan : AppColors.textMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.cyberCyan : AppColors.textMuted,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

