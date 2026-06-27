import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/providers/package_info_provider.dart';
import '../core/services/mei_logger.dart';
import '../core/services/storage/storage_service.dart';
import 'app.dart';

/// Production app bootstrap
///
/// Handles all initialization before running the app.
/// Errors during bootstrap are caught and logged.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();

  // System orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Global error handling
  FlutterError.onError = (details) {
    log.e(
      'Flutter error: ${details.exceptionAsString()}',
      details.exception,
      details.stack,
    );
  };

  log.i('Mei Converter starting up...');

  // Initialize storage
  await StorageService.init();

  // Initialize package info
  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    ProviderScope(
      overrides: [
        packageInfoProvider.overrideWithValue(packageInfo),
      ],
      child: const MeiConvertorApp(),
    ),
  );
}
