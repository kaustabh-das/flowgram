import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../router/app_router.dart';

/// Persistent shell with a solid dark bottom navigation bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const _routes = [
    AppRoutes.home,
    AppRoutes.editor,
    AppRoutes.templates,
  ];

  int _routeToIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (int i = _routes.length - 1; i >= 0; i--) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _routeToIndex(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: false,
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 24.0),
        child: FloatingActionButton(
          onPressed: () => context.go(AppRoutes.editor),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 32),
        ),
      ),
      bottomNavigationBar: Container(
        height: 64 + bottomPadding,
        padding: EdgeInsets.only(bottom: bottomPadding),
        decoration: const BoxDecoration(
          color: Color(0xFF141414), 
          border: Border(top: BorderSide(color: Colors.white10, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _AnimatedNavItem(
              icon: Icons.image_outlined,
              activeIcon: Icons.image_rounded,
              label: 'Photo',
              isSelected: currentIndex == 0,
              onTap: () => context.go(AppRoutes.home),
            ),
            const SizedBox(width: 48), 
            _AnimatedNavItem(
              icon: Icons.bolt_outlined,
              activeIcon: Icons.bolt_rounded,
              label: 'Ai Effects',
              isSelected: currentIndex == 2,
              onTap: () => context.go(AppRoutes.templates),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedNavItem extends StatelessWidget {
  const _AnimatedNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 80,
        height: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 26,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
