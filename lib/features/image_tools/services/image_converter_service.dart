import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../../core/errors/failures.dart';
import '../../../core/services/mei_logger.dart';
import '../../../core/utils/file_utils.dart';

/// Converts, compresses and resizes images.
/// All heavy work runs on a background isolate via [compute].
class ImageConverterService {
  const ImageConverterService._();

  static const List<String> _supported = ['jpg', 'jpeg', 'png', 'webp', 'bmp'];

  /// Returns `true` if both extensions are supported.
  static bool supports(String fromExt, String toExt) =>
      _supported.contains(fromExt.toLowerCase()) &&
      _supported.contains(toExt.toLowerCase());

  // ── Format conversion ─────────────────────────────────────────────────────

  /// Converts [sourcePath] to [targetExt] format.
  static Future<String> convert(String sourcePath, String targetExt) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const FileNotFoundFailure(message: 'Source file not found.');
    }
    FileUtils.assertSizeOk(source);

    final outputPath = await FileUtils.buildOutputPath(sourcePath, targetExt);

    if (targetExt.toLowerCase() == 'webp') {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        try {
          final result = await FlutterImageCompress.compressAndGetFile(
            sourcePath,
            outputPath,
            quality: 90,
            format: CompressFormat.webp,
          );
          if (result != null) {
            MeiLogger.instance.i('Converted via native ${p.basename(sourcePath)} → webp');
            return result.path;
          }
        } catch (e) {
          MeiLogger.instance.w('Native WebP conversion failed: $e');
        }
      }
      throw const ConversionFailure(
        message: 'WebP encoding is not supported on this platform.',
      );
    }

    final bytes = await source.readAsBytes();
    final resultBytes = await compute(_encodeImage, _EncodeArgs(bytes, targetExt));
    await File(outputPath).writeAsBytes(resultBytes);
    MeiLogger.instance.i('Converted ${p.basename(sourcePath)} → $targetExt');
    return outputPath;
  }

  // ── Compression ───────────────────────────────────────────────────────────

  /// Compresses [sourcePath] to [quality] (1–100) and saves as JPEG.
  /// Uses flutter_image_compress for maximum native speed, falls back to pure Dart on desktop.
  static Future<String> compress(
    String sourcePath, {
    int quality = 80,
  }) async {
    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const FileNotFoundFailure(message: 'Source file not found.');
    }
    FileUtils.assertSizeOk(source);

    final ext = p.extension(sourcePath).replaceAll('.', '').toLowerCase();
    // Output as JPEG for best compression ratio
    final outputPath = await FileUtils.buildOutputPath(sourcePath, 'jpg');

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final result = await FlutterImageCompress.compressAndGetFile(
          sourcePath,
          outputPath,
          quality: quality.clamp(1, 100),
          format: CompressFormat.jpeg,
        );

        if (result != null) {
          MeiLogger.instance.i(
            'Compressed via native ${p.basename(sourcePath)} '
            '[q=$quality, ext=$ext] → ${p.basename(outputPath)}',
          );
          return result.path;
        }
      } catch (e) {
        MeiLogger.instance.w('Native compression failed, falling back to pure Dart: $e');
      }
    }

    // Pure Dart fallback for macOS/desktop/web
    final bytes = await source.readAsBytes();
    final resultBytes = await compute(
      _compressImageIsolate,
      _CompressArgs(bytes, quality.clamp(1, 100)),
    );
    await File(outputPath).writeAsBytes(resultBytes);

    MeiLogger.instance.i(
      'Compressed via Dart ${p.basename(sourcePath)} '
      '[q=$quality, ext=$ext] → ${p.basename(outputPath)}',
    );
    return outputPath;
  }

  // ── Resize ────────────────────────────────────────────────────────────────

  /// Resizes [sourcePath] to [targetWidth]×[targetHeight] pixels.
  /// Pass null for one dimension to preserve aspect ratio.
  static Future<String> resize(
    String sourcePath, {
    int? targetWidth,
    int? targetHeight,
  }) async {
    if (targetWidth == null && targetHeight == null) {
      throw ArgumentError('At least one of targetWidth/targetHeight must be set.');
    }

    final source = File(sourcePath);
    if (!source.existsSync()) {
      throw const FileNotFoundFailure(message: 'Source file not found.');
    }
    FileUtils.assertSizeOk(source);

    final bytes = await source.readAsBytes();
    final ext = p.extension(sourcePath).replaceAll('.', '').toLowerCase();
    final outputPath = await FileUtils.buildOutputPath(sourcePath, ext);

    final resultBytes = await compute(
      _resizeImage,
      _ResizeArgs(bytes, targetWidth, targetHeight, ext),
    );

    await File(outputPath).writeAsBytes(resultBytes);
    MeiLogger.instance.i(
      'Resized ${p.basename(sourcePath)} → ${targetWidth}x$targetHeight',
    );
    return outputPath;
  }

  /// Returns the width × height of an image without full decode.
  static Future<({int width, int height})> getDimensions(
    String sourcePath,
  ) async {
    final bytes = await File(sourcePath).readAsBytes();
    return compute(_getDimensions, bytes);
  }
}

// ── Isolate helpers ───────────────────────────────────────────────────────────

class _EncodeArgs {
  const _EncodeArgs(this.bytes, this.targetExt);
  final Uint8List bytes;
  final String targetExt;
}

Uint8List _encodeImage(_EncodeArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) throw Exception('Failed to decode image');

  return switch (args.targetExt.toLowerCase()) {
    'jpg' || 'jpeg' => Uint8List.fromList(img.encodeJpg(decoded, quality: 90)),
    'png'           => Uint8List.fromList(img.encodePng(decoded)),
    'bmp'           => Uint8List.fromList(img.encodeBmp(decoded)),
    _ => throw Exception('Unsupported target: ${args.targetExt}'),
  };
}

class _CompressArgs {
  const _CompressArgs(this.bytes, this.quality);
  final Uint8List bytes;
  final int quality;
}

Uint8List _compressImageIsolate(_CompressArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) throw Exception('Failed to decode image');
  return Uint8List.fromList(img.encodeJpg(decoded, quality: args.quality));
}

class _ResizeArgs {
  const _ResizeArgs(this.bytes, this.targetWidth, this.targetHeight, this.ext);
  final Uint8List bytes;
  final int? targetWidth;
  final int? targetHeight;
  final String ext;
}

Uint8List _resizeImage(_ResizeArgs args) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) throw Exception('Failed to decode image for resize');

  final resized = img.copyResize(
    decoded,
    width: args.targetWidth,
    height: args.targetHeight,
    interpolation: img.Interpolation.cubic,
  );

  return switch (args.ext) {
    'jpg' || 'jpeg' => Uint8List.fromList(img.encodeJpg(resized, quality: 92)),
    'png'           => Uint8List.fromList(img.encodePng(resized)),
    'bmp'           => Uint8List.fromList(img.encodeBmp(resized)),
    _               => Uint8List.fromList(img.encodeJpg(resized, quality: 92)),
  };
}

({int width, int height}) _getDimensions(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Failed to decode image');
  return (width: decoded.width, height: decoded.height);
}
