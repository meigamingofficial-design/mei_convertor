import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../mei_logger.dart';

/// Handles sharing and opening converted files.
class SharingService {
  const SharingService._();

  /// Share a single file. [subject] shows up on email/some receivers.
  static Future<void> shareFile(
    String filePath, {
    String? subject,
    String? message,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        MeiLogger.instance.w('share: file not found at $filePath');
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          subject: subject,
          text: message,
        ),
      );
    } catch (e, st) {
      MeiLogger.instance.e('shareFile failed', e, st);
    }
  }

  /// Share multiple files at once.
  static Future<void> shareFiles(
    List<String> filePaths, {
    String? subject,
  }) async {
    try {
      final xFiles = filePaths
          .where((p) => File(p).existsSync())
          .map(XFile.new)
          .toList();

      if (xFiles.isEmpty) {
        MeiLogger.instance.w('shareFiles: no valid files to share');
        return;
      }
      await SharePlus.instance.share(
        ShareParams(files: xFiles, subject: subject),
      );
    } catch (e, st) {
      MeiLogger.instance.e('shareFiles failed', e, st);
    }
  }

  /// Open a file with the OS default viewer.
  static Future<bool> openFile(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      final ok = result.type == ResultType.done;
      if (!ok) MeiLogger.instance.w('openFile: ${result.message}');
      return ok;
    } catch (e, st) {
      MeiLogger.instance.e('openFile failed', e, st);
      return false;
    }
  }

  /// Returns true if the file exists on disk.
  static bool fileExists(String path) => File(path).existsSync();

  /// Returns the app-specific output directory for converted files.
  static Future<Directory> getOutputDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final out = Directory('${base.path}/MeiConvertor/Output');
    if (!out.existsSync()) {
      await out.create(recursive: true);
    }
    return out;
  }
}
