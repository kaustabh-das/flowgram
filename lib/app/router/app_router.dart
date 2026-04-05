import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/editor/presentation/editor_screen.dart';
import '../../features/templates/presentation/templates_screen.dart';
import '../../features/templates/presentation/story_editor_screen.dart';
import '../shell/app_shell.dart';

// ── Route paths ──────────────────────────────────────────────────────────────
abstract class AppRoutes {
  static const home      = '/';
  static const editor    = '/editor';
  static const templates = '/templates';
  static const storyEditor = '/story_editor';
  // Legacy – keeping gallery accessible but not in bottom nav
  static const gallery   = '/gallery';
}

// ── Router provider ──────────────────────────────────────────────────────────
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.home,
    debugLogDiagnostics: true,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: AppRoutes.editor,
            pageBuilder: (context, state) {
              final imagePath = state.uri.queryParameters['path'];
              return CustomTransitionPage(
                child: EditorScreen(imagePath: imagePath),
                transitionDuration: const Duration(milliseconds: 320),
                transitionsBuilder: (context, animation, _, child) =>
                    FadeTransition(
                  opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                    child: child,
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.templates,
            pageBuilder: (context, state) => CustomTransitionPage(
              child: const TemplatesScreen(),
              transitionDuration: const Duration(milliseconds: 280),
              transitionsBuilder: (context, animation, _, child) =>
                  FadeTransition(
                opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
                child: child,
              ),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.storyEditor,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            child: StoryEditorScreen(
              layoutId: (state.uri.queryParameters['layoutId'] ?? 'story_split'),
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
