import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/documents/presentation/documents_screen.dart';
import '../features/home/presentation/all_tools_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/image_tools/presentation/image_tools_screen.dart';
import '../features/pdf_tools/presentation/pdf_tools_screen.dart';
import '../features/quick_convert/presentation/quick_convert_screen.dart';
import '../features/recent_files/presentation/recent_files_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

/// Route name constants
abstract final class MeiRoutes {
  static const String home = '/';
  static const String quickConvert = '/quick-convert';
  static const String imageTools = '/image-tools';
  static const String pdfTools = '/pdf-tools';
  static const String documents = '/documents';
  static const String recentFiles = '/recent-files';
  static const String allTools = '/tools';
  static const String settings = '/settings';
}

/// Mei Convertor app router using GoRouter
final class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: MeiRoutes.home,
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: MeiRoutes.home,
        name: 'home',
        pageBuilder: (context, state) => _buildPage(
          state,
          const HomeScreen(),
        ),
      ),
      GoRoute(
        path: MeiRoutes.quickConvert,
        name: 'quick-convert',
        pageBuilder: (context, state) => _buildPage(
          state,
          const QuickConvertScreen(),
        ),
      ),
      GoRoute(
        path: MeiRoutes.imageTools,
        name: 'image-tools',
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          return _buildPage(
            state,
            ImageToolsScreen(initialTabName: tab),
          );
        },
      ),
      GoRoute(
        path: MeiRoutes.pdfTools,
        name: 'pdf-tools',
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          return _buildPage(
            state,
            PdfToolsScreen(initialTabName: tab),
          );
        },
      ),
      GoRoute(
        path: MeiRoutes.documents,
        name: 'documents',
        pageBuilder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          return _buildPage(
            state,
            DocumentsScreen(initialTabName: tab),
          );
        },
      ),
      GoRoute(
        path: MeiRoutes.recentFiles,
        name: 'recent-files',
        pageBuilder: (context, state) => _buildPage(
          state,
          const RecentFilesScreen(),
        ),
      ),
      GoRoute(
        path: MeiRoutes.allTools,
        name: 'all-tools',
        pageBuilder: (context, state) => _buildPage(
          state,
          const AllToolsScreen(),
        ),
      ),
      GoRoute(
        path: MeiRoutes.settings,
        name: 'settings',
        pageBuilder: (context, state) => _buildPage(
          state,
          const SettingsScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );

  /// Smooth fade+slide page transition
  static CustomTransitionPage<void> _buildPage(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeTween = CurveTween(curve: Curves.easeInOut);
        final slideTween = Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
      },
    );
  }
}
