import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../config/theme.dart';
import '../../config/routes.dart';

/// Client Main Screen - Shell with Bottom Navigation
class ClientMainScreen extends StatelessWidget {
  final Widget child;

  const ClientMainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const _ClientBottomNav(),
    );
  }
}

class _ClientBottomNav extends StatelessWidget {
  const _ClientBottomNav();

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/client/search')) return 1;
    if (location.startsWith('/client/upcoming')) return 2;
    if (location.startsWith('/client/bookings')) return 3;
    if (location.startsWith('/client/profile')) return 4;
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
            color: AppColors.neonPurple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _NavItem(
                  icon: Iconsax.home,
                  activeIcon: Iconsax.home_15,
                  label: 'Home',
                  isSelected: selectedIndex == 0,
                  onTap: () => context.go(Routes.clientHome),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Iconsax.search_normal,
                  activeIcon: Iconsax.search_normal_1,
                  label: 'Search',
                  isSelected: selectedIndex == 1,
                  onTap: () => context.go(Routes.search),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.rocket_launch,
                  activeIcon: Icons.rocket_launch,
                  label: 'Upcoming',
                  isSelected: selectedIndex == 2,
                  onTap: () => context.go(Routes.upcomingFeatures),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Iconsax.calendar,
                  activeIcon: Iconsax.calendar_1,
                  label: 'Bookings',
                  isSelected: selectedIndex == 3,
                  onTap: () => context.go(Routes.myBookings),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Iconsax.user,
                  activeIcon: Iconsax.user,
                  label: 'Profile',
                  isSelected: selectedIndex == 4,
                  onTap: () => context.go(Routes.clientProfile),
                ),
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.neonPurple.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.neonPurple : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.neonPurple : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

