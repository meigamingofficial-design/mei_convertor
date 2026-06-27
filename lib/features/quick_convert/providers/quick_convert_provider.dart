import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../core/models/conversion_record.dart';
import '../../../core/services/converters/file_type_detector_service.dart';
import '../../../core/services/mei_logger.dart';
import '../../../core/utils/file_utils.dart';
import '../../documents/services/document_converter_service.dart';
import '../../image_tools/services/image_converter_service.dart';
import '../../pdf_tools/services/pdf_converter_service.dart';
import '../../recent_files/providers/history_provider.dart';

// ── State ─────────────────────────────────────────────────────────────────────

enum QuickConvertStatus { idle, detecting, converting, done, failed }

class QuickConvertState {
  const QuickConvertState({
    this.status = QuickConvertStatus.idle,
    this.sourcePath,
    this.detectedType,
    this.targetFormat,
    this.outputPath,
    this.failure,
  });

  final QuickConvertStatus status;
  final String? sourcePath;
  final MeiFileCategory? detectedType;
  final String? targetFormat;
  final String? outputPath;
  final MeiFailure? failure;

  bool get hasSource => sourcePath != null;
  bool get isDetected => detectedType != null;
  bool get isBusy => status == QuickConvertStatus.converting;

  QuickConvertState copyWith({
    QuickConvertStatus? status,
    String? sourcePath,
    MeiFileCategory? detectedType,
    String? targetFormat,
    String? outputPath,
    MeiFailure? failure,
  }) =>
      QuickConvertState(
        status: status ?? this.status,
        sourcePath: sourcePath ?? this.sourcePath,
        detectedType: detectedType ?? this.detectedType,
        targetFormat: targetFormat ?? this.targetFormat,
        outputPath: outputPath ?? this.outputPath,
        failure: failure ?? this.failure,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class QuickConvertNotifier extends Notifier<QuickConvertState> {
  static final _log = MeiLogger.instance;
  static const _uuid = Uuid();

  @override
  QuickConvertState build() => const QuickConvertState();

  Future<void> setSource(String path) async {
    state = QuickConvertState(
      sourcePath: path,
      status: QuickConvertStatus.detecting,
    );

    final fileType = FileTypeDetectorService.detectFromPath(path);
    state = state.copyWith(
      status: QuickConvertStatus.idle,
      detectedType: fileType.category,
      targetFormat: _defaultTarget(fileType.extension),
    );
  }

  void setTargetFormat(String format) {
    state = state.copyWith(targetFormat: format);
  }

  Future<void> convert() async {
    if (state.sourcePath == null || state.targetFormat == null) return;

    // Reset output / errors, mark as converting
    state = QuickConvertState(
      status: QuickConvertStatus.converting,
      sourcePath: state.sourcePath,
      detectedType: state.detectedType,
      targetFormat: state.targetFormat,
    );

    try {
      var outputPath = await _dispatch(
        sourcePath: state.sourcePath!,
        targetFormat: state.targetFormat!,
        category: state.detectedType ?? MeiFileCategory.unknown,
      );
      outputPath = await FileUtils.moveToPublic(outputPath);

      // Verify output exists
      final outFile = File(outputPath);
      if (!outFile.existsSync()) {
        throw const ConversionFailure(
          message: 'Conversion completed but output file was not found.',
        );
      }

      // Persist to history
      await _saveHistory(
        sourcePath: state.sourcePath!,
        outputPath: outputPath,
        targetFormat: state.targetFormat!,
        category: state.detectedType ?? MeiFileCategory.unknown,
      );

      state = state.copyWith(
        status: QuickConvertStatus.done,
        outputPath: outputPath,
      );
    } catch (e, st) {
      _log.e('QuickConvert failed', e, st);
      state = state.copyWith(
        status: QuickConvertStatus.failed,
        failure: e is MeiFailure
            ? e
            : ConversionFailure(message: e.toString(), cause: e),
      );
    }
  }

  void convertAnother() {
    state = state.copyWith(
      status: QuickConvertStatus.idle,
      outputPath: null,
      failure: null,
    );
  }

  void reset() => state = const QuickConvertState();

  // ── Conversion router ─────────────────────────────────────────────────────

  Future<String> _dispatch({
    required String sourcePath,
    required String targetFormat,
    required MeiFileCategory category,
  }) async {
    final srcExt = sourcePath.split('.').last.toLowerCase();

    // ── Compress ──────────────────────────────────────────────────────────
    if (targetFormat == 'compress') {
      if (category == MeiFileCategory.image) {
        return ImageConverterService.compress(sourcePath);
      }
      throw const UnsupportedFormatFailure(
        message: 'Compression is only supported for images.',
      );
    }

    // ── Resize (redirect) ─────────────────────────────────────────────────
    if (targetFormat == 'resize') {
      throw const UnsupportedFormatFailure(
        message: 'Resize requires dimension inputs. Please use Image Tools.',
      );
    }

    // ── → PDF ──────────────────────────────────────────────────────────────
    if (targetFormat == 'pdf') {
      if (category == MeiFileCategory.image) {
        return PdfConverterService.imagesToPdf([sourcePath]);
      }
      if (category == MeiFileCategory.text) {
        // Plain text → PDF
        return PdfConverterService.textToPdf(sourcePath);
      }
      if (category == MeiFileCategory.document) {
        // DOCX / DOC → extract text → create PDF
        return _docxToPdf(sourcePath);
      }
      throw const UnsupportedFormatFailure(
        message: 'Cannot convert this file type to PDF.',
      );
    }

    // ── → DOCX ────────────────────────────────────────────────────────────
    if (targetFormat == 'docx') {
      if (category == MeiFileCategory.text) {
        return DocumentConverterService.convertToDocx(sourcePath);
      }
      throw const UnsupportedFormatFailure(
        message: 'DOCX generation is only supported from .txt files.',
      );
    }

    // ── → TXT ─────────────────────────────────────────────────────────────
    if (targetFormat == 'txt') {
      if (category == MeiFileCategory.document &&
          (srcExt == 'docx' || srcExt == 'doc')) {
        // DOCX → extract plain text → save as .txt
        return _docxToTxt(sourcePath);
      }
      // Text file copy / re-encode (existing behaviour for other doc types)
      return _copyAsText(sourcePath);
    }

    // ── Image format conversions ───────────────────────────────────────────
    if (category == MeiFileCategory.image) {
      return ImageConverterService.convert(sourcePath, targetFormat);
    }

    throw const UnsupportedFormatFailure(
      message: 'This conversion is not yet supported.',
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  /// DOCX → extract text → save as .txt file
  Future<String> _docxToTxt(String docxPath) async {
    final text = await DocumentConverterService.extractDocxText(docxPath);
    if (text.isEmpty) {
      throw const ConversionFailure(
        message:
            'The document appears to be empty or contains no readable text.',
      );
    }
    final outputPath = await FileUtils.buildOutputPath(docxPath, 'txt');
    await File(outputPath).writeAsString(text);
    return outputPath;
  }

  /// DOCX → extract text → create PDF
  Future<String> _docxToPdf(String docxPath) async {
    final text = await DocumentConverterService.extractDocxText(docxPath);
    if (text.isEmpty) {
      throw const ConversionFailure(
        message: 'The document appears to be empty — nothing to convert to PDF.',
      );
    }

    // Write extracted text to a temp .txt, then use the PDF service
    final tmp = await FileUtils.tempDir();
    final stem = docxPath.split('/').last.replaceAll('.', '_');
    final tmpTxt = File('${tmp.path}/${stem}_extracted.txt');
    await tmpTxt.writeAsString(text);

    final pdfPath = await PdfConverterService.textToPdf(tmpTxt.path);

    // Rename output so the stem matches the original DOCX filename
    final outDir = await FileUtils.outputDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final finalBase = docxPath.split('/').last.split('.').first;
    final finalPath = '${outDir.path}/${finalBase}_$ts.pdf';
    await File(pdfPath).rename(finalPath);

    return finalPath;
  }

  /// Copies / re-encodes a plain text file (fallback for unsupported doc formats).
  Future<String> _copyAsText(String sourcePath) async {
    final content = await File(sourcePath).readAsString();
    final outputPath = await FileUtils.buildOutputPath(sourcePath, 'txt');
    await File(outputPath).writeAsString(content);
    return outputPath;
  }

  Future<void> _saveHistory({
    required String sourcePath,
    required String outputPath,
    required String targetFormat,
    required MeiFileCategory category,
  }) async {
    try {
      final size = File(outputPath).statSync().size;
      final inputExt = FileTypeDetectorService.detectFromPath(sourcePath).extension;
      final record = ConversionRecord(
        id: _uuid.v4(),
        inputFileName: sourcePath.split('/').last,
        inputPath: sourcePath,
        outputPath: outputPath,
        inputFormat: inputExt,
        outputFormat: targetFormat,
        fileSizeBytes: size,
        convertedAt: DateTime.now(),
        categoryName: category.name,
      );
      await ref.read(historyProvider.notifier).add(record);
    } catch (e) {
      _log.w('Failed to persist quick convert history: $e');
    }
  }
}

/// Returns a sensible default target format given the source file extension.
String? _defaultTarget(String ext) => switch (ext) {
      'jpg' || 'jpeg' => 'png',
      'png'           => 'jpg',
      'webp'          => 'jpg',
      'bmp'           => 'png',
      'gif'           => 'png',
      'txt'           => 'docx',   // TXT now defaults to DOCX in Quick Convert
      'md'            => 'pdf',
      'docx' || 'doc' => 'txt',    // DOCX/DOC defaults to text extraction
      _               => null,
    };

final quickConvertProvider =
    NotifierProvider<QuickConvertNotifier, QuickConvertState>(
  QuickConvertNotifier.new,
);
