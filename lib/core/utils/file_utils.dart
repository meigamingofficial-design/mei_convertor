import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../services/mei_logger.dart';

/// General-purpose file utilities: temp dirs, size checks, extension checks.
class FileUtils {
  const FileUtils._();

  static final _log = MeiLogger.instance;

  // ── Directories ──────────────────────────────────────────────────────────

  /// Returns (and creates if needed) the app's output directory.
  static Future<Directory> outputDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'MeiConvertor', 'Output'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
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
