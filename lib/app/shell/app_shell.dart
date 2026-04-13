import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../router/app_router.dart';

/// Persistent shell with a solid dark bottom navigation bar.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBackPressTime;

  static const _routes = [
    AppRoutes.home,
    AppRoutes.video,
    AppRoutes.templates,
    AppRoutes.projects,
  ];

  int _routeToIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.editor) ||
        location.startsWith(AppRoutes.storyEditor)) return -1;
    for (int i = _routes.length - 1; i >= 0; i--) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  bool _isOnHome(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    return location == AppRoutes.home || location == '/';
  }

  Future<bool> _onBackPressed(BuildContext context) async {
    // If not on the home tab, navigate there first.
    if (!_isOnHome(context)) {
      context.go(AppRoutes.home);
      return false; // Do not pop/exit.
    }

    // Already on home — show "press again to exit" toast.
    final now = DateTime.now();
    final isSecondPress = _lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < const Duration(seconds: 2);

    if (isSecondPress) {
      return true; // Allow exit on second press.
    }

    _lastBackPressTime = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Press back again to exit'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return false; // Block exit on first press.
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _routeToIndex(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onBackPressed(context);
        if (shouldPop && context.mounted) {
          // Allow the app to exit by popping the navigator directly.
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBody: false,
        body: widget.child,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        // On editor routes: null (not SizedBox.shrink) so Scaffold gives the
        // editor full body height and correct MediaQuery.padding.bottom.
        floatingActionButton: currentIndex == -1
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: FloatingActionButton(
                  onPressed: () => context.push(AppRoutes.editor),
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  elevation: 4,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add_rounded, size: 32),
                ),
              ),
        bottomNavigationBar: currentIndex == -1
            ? null
            : Container(
                height: 64 + bottomPadding,
                padding: EdgeInsets.only(bottom: bottomPadding),
                decoration: const BoxDecoration(
                  color: Color(0xFF141414),
                  border: Border(top: BorderSide(color: Colors.white10, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AnimatedNavItem(
                      icon: Icons.image_outlined,
                      activeIcon: Icons.image_rounded,
                      label: 'Photo',
                      isSelected: currentIndex == 0,
                      onTap: () => context.go(AppRoutes.home),
                    ),
                    _AnimatedNavItem(
                      icon: Icons.play_circle_outline_rounded,
                      activeIcon: Icons.play_circle_filled_rounded,
                      label: 'Video',
                      isSelected: currentIndex == 1,
                      onTap: () => context.go(AppRoutes.video),
                    ),
                    const SizedBox(width: 48),
                    _AnimatedNavItem(
                      icon: Icons.bolt_outlined,
                      activeIcon: Icons.bolt_rounded,
                      label: 'Templates',
                      isSelected: currentIndex == 2,
                      onTap: () => context.go(AppRoutes.templates),
                    ),
                    _AnimatedNavItem(
                      icon: Icons.folder_outlined,
                      activeIcon: Icons.folder_rounded,
                      label: 'Projects',
                      isSelected: currentIndex == 3,
                      onTap: () => context.go(AppRoutes.projects),
                    ),
                  ],
                ),
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
        width: 70,
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
