import 'dart:async';

/// Result type for all conversion operations
sealed class ConversionResult<T> {
  const ConversionResult();
}

final class ConversionSuccess<T> extends ConversionResult<T> {
  const ConversionSuccess(this.data, {this.outputPath});
  final T data;
  final String? outputPath;
}

final class ConversionFailure<T> extends ConversionResult<T> {
  const ConversionFailure(this.error, [this.stackTrace]);
  final Object error;
  final StackTrace? stackTrace;
}

final class ConversionProgress<T> extends ConversionResult<T> {
  const ConversionProgress(this.progress, this.message);
  final double progress; // 0.0 to 1.0
  final String message;
}

/// Base interface for all converter services
abstract interface class ConverterService {
  /// Unique identifier for this converter
  String get id;

  /// Human-readable name
  String get displayName;

  /// Supported input extensions
  List<String> get supportedInputs;

  /// Supported output extensions
  List<String> get supportedOutputs;

  /// Whether this converter can handle isolate processing
  bool get supportsIsolate;

  /// Convert a file — runs in isolate if [supportsIsolate] is true
  Future<ConversionResult<String>> convert({
    required String inputPath,
    required String outputPath,
    required String targetFormat,
    Map<String, dynamic> options,
    void Function(double progress, String message)? onProgress,
  });
}
