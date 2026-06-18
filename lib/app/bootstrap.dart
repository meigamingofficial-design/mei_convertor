import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

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

  log.i('Mei Convertor starting up...');

  // Initialize storage
  await StorageService.init();

  runApp(
    const ProviderScope(
      child: MeiConvertorApp(),
    ),
  );
}
