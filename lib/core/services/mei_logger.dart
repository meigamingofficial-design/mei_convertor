import 'package:logger/logger.dart';

/// Structured logging service for Mei Convertor
/// 
/// Wraps the `logger` package with app-level configuration.
/// In release mode, only warnings and above are printed.
/// Crash-safe: all methods handle exceptions internally.
final class MeiLogger {
  MeiLogger._();

  static final MeiLogger _instance = MeiLogger._();
  static MeiLogger get instance => _instance;

  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: Level.debug,
  );

  void d(String message, [Object? error, StackTrace? stackTrace]) {
    try {
      _logger.d(message, error: error, stackTrace: stackTrace);
    } catch (_) {}
  }

  void i(String message, [Object? error, StackTrace? stackTrace]) {
    try {
      _logger.i(message, error: error, stackTrace: stackTrace);
    } catch (_) {}
  }

  void w(String message, [Object? error, StackTrace? stackTrace]) {
    try {
      _logger.w(message, error: error, stackTrace: stackTrace);
    } catch (_) {}
  }

  void e(String message, [Object? error, StackTrace? stackTrace]) {
    try {
      _logger.e(message, error: error, stackTrace: stackTrace);
    } catch (_) {}
  }

  void wtf(String message, [Object? error, StackTrace? stackTrace]) {
    try {
      _logger.f(message, error: error, stackTrace: stackTrace);
    } catch (_) {}
  }
}

/// Convenience global accessor
final log = MeiLogger.instance;
