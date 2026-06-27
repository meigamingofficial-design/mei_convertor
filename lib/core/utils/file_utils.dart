import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../services/mei_logger.dart';

/// General-purpose file utilities: temp dirs, size checks, extension checks.
class FileUtils {
  const FileUtils._();

  static final _log = MeiLogger.instance;
  static const _channel = MethodChannel('com.meigaming.meiconvertor/files');

  // ── Directories ──────────────────────────────────────────────────────────

  /// Returns (and creates if needed) the app's output directory.
  static Future<Directory> outputDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'MeiConvertor'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  /// Moves/saves a completed file to the public storage if on Android,
  /// returning the final path.
  static Future<String> moveToPublic(String internalPath) async {
    if (Platform.isAndroid) {
      try {
        final file = File(internalPath);
        if (!file.existsSync()) return internalPath;

        final fileName = p.basename(internalPath);
        final extension = p.extension(internalPath).replaceAll('.', '').toLowerCase();

        // Determine mime type
        String? mimeType;
        if (extension == 'pdf') {
          mimeType = 'application/pdf';
        } else if (extension == 'jpg' || extension == 'jpeg') {
          mimeType = 'image/jpeg';
        } else if (extension == 'png') {
          mimeType = 'image/png';
        } else if (extension == 'webp') {
          mimeType = 'image/webp';
        } else if (extension == 'bmp') {
          mimeType = 'image/bmp';
        } else if (extension == 'docx') {
          mimeType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
        } else if (extension == 'txt') {
          mimeType = 'text/plain';
        }

        final String? publicPath = await _channel.invokeMethod<String>('saveFileToPublic', {
          'tempPath': internalPath,
          'fileName': fileName,
          'mimeType': mimeType,
        });

        if (publicPath != null && publicPath.isNotEmpty) {
          // Delete the temporary internal file
          await deleteIfExists(internalPath);
          return publicPath;
        }
      } catch (e) {
        _log.e('Failed to save file to public storage: $e');
      }
    }
    return internalPath;
  }

  /// Returns (and creates if needed) a temp scratch dir for in-progress work.
  static Future<Directory> tempDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'MeiConvertor'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  // ── Validation ────────────────────────────────────────────────────────────

  /// Throws a [FileTooLargeFailure] if [file] exceeds the max size.
  static void assertSizeOk(File file) {
    final stat = file.statSync();
    if (stat.size > MeiFormats.maxFileSizeBytes) {
      throw FileTooLargeFailure(
        message:
            'File is ${stat.size} bytes but the limit is ${MeiFormats.maxFileSizeBytes} bytes.',
      );
    }
  }

  /// Returns `true` if [extension] (without dot, any case) is an image format.
  static bool isImage(String extension) =>
      MeiFormats.imageExtensions.contains(extension.toLowerCase());

  /// Returns `true` if [extension] is a PDF format.
  static bool isPdf(String extension) =>
      MeiFormats.pdfExtensions.contains(extension.toLowerCase());

  /// Returns `true` if [extension] is a document format.
  static bool isDocument(String extension) =>
      MeiFormats.documentExtensions.contains(extension.toLowerCase());

  // ── Path helpers ──────────────────────────────────────────────────────────

  /// Builds a unique output path for a converted file, e.g.:
  /// `<outputDir>/photo_1716900000.png`
  static Future<String> buildOutputPath(
    String sourcePath,
    String targetExtension,
  ) async {
    final dir = await outputDir();
    final stem = p.basenameWithoutExtension(sourcePath);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, '${stem}_$ts.$targetExtension');
  }

  /// Deletes a file, swallowing errors gracefully.
  static Future<void> deleteIfExists(String path) async {
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (e) {
      _log.w('Could not delete file at $path: $e');
    }
  }

  /// Copies [source] to [destination], creating parent dirs as needed.
  static Future<File> copyTo(String source, String destination) async {
    final destFile = File(destination);
    await destFile.parent.create(recursive: true);
    return File(source).copy(destination);
  }
}
