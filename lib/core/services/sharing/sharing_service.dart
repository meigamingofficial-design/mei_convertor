import 'dart:io';

import 'package:flutter/services.dart';
import 'package:open_file_manager/open_file_manager.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../mei_logger.dart';

/// Handles sharing and opening converted files.
class SharingService {
  const SharingService._();

  static const _channel = MethodChannel('com.meigaming.meiconvertor/files');

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
      if (Platform.isAndroid) {
        // Use native intent with chooser for reliable "Open with" on all Android devices
        await _channel.invokeMethod('openFile', {'path': filePath});
        return true;
      }
      final result = await OpenFilex.open(filePath);
      final ok = result.type == ResultType.done;
      if (!ok) MeiLogger.instance.w('openFile: ${result.message}');
      return ok;
    } catch (e, st) {
      MeiLogger.instance.e('openFile failed', e, st);
      return false;
    }
  }

  /// Open a folder in the system file manager.
  static Future<bool> openFolder(String folderPath) async {
    try {
      if (Platform.isIOS) {
        final relativePath = folderPath.contains('/MeiConvertor')
            ? 'MeiConvertor'
            : '';
        await openFileManager(
          iosConfig: IosConfig(
            folderPath: relativePath,
          ),
        );
        return true;
      } else if (Platform.isAndroid) {
        // Use the native MethodChannel which has multi-strategy fallbacks
        // (DocumentsContract, Content URI, File URI) to open the system
        // file manager at the correct Documents/MeiConvertor folder.
        await _channel.invokeMethod('openFolder', {'path': folderPath});
        return true;
      } else {
        final result = await OpenFilex.open(folderPath);
        final ok = result.type == ResultType.done;
        if (!ok) MeiLogger.instance.w('openFolder: ${result.message}');
        return ok;
      }
    } catch (e, st) {
      MeiLogger.instance.e('openFolder failed', e, st);
      return false;
    }
  }

  /// Returns true if the file exists on disk.
  static bool fileExists(String path) => File(path).existsSync();

  /// Returns the app-specific output directory for converted files.
  static Future<Directory> getOutputDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final out = Directory('${base.path}/MeiConvertor');
    if (!out.existsSync()) {
      await out.create(recursive: true);
    }
    return out;
  }

  /// Launch a URL in the default system browser.
  static Future<void> openUrl(String url) async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('openUrl', {'url': url});
      } else {
        MeiLogger.instance.w('openUrl is not supported on this platform: $url');
      }
    } catch (e, st) {
      MeiLogger.instance.e('openUrl failed', e, st);
    }
  }
}
