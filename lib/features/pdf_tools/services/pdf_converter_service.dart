import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../core/models/conversion_record.dart';
import '../../../core/services/mei_logger.dart';
import '../../../core/utils/file_utils.dart';
import '../../recent_files/providers/history_provider.dart';

// ── Service ───────────────────────────────────────────────────────────────────

class PdfConverterService {
  const PdfConverterService._();

  // ── Images → PDF ────────────────────────────────────────────────────────────

  /// Wraps one or more image files into a single PDF document.
  static Future<String> imagesToPdf(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      throw const ConversionFailure(message: 'No images provided.');
    }
    final pdf = pw.Document();

    for (final path in imagePaths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;

      final pngBytes = img.encodePng(decoded);
      final pdfImage = pw.MemoryImage(Uint8List.fromList(pngBytes));
      pdf.addPage(
        pw.Page(
          margin: pw.EdgeInsets.zero,
          pageFormat: PdfPageFormat(
            decoded.width.toDouble(),
            decoded.height.toDouble(),
          ),
          build: (_) => pw.Image(pdfImage, fit: pw.BoxFit.contain),
        ),
      );
    }

    final outputPath = await FileUtils.buildOutputPath(imagePaths.first, 'pdf');
    await File(outputPath).writeAsBytes(await pdf.save());
    MeiLogger.instance.i('PDF created: $outputPath (${imagePaths.length} pages)');
    return outputPath;
  }

  // ── TXT → PDF ──────────────────────────────────────────────────────────────

  /// Converts a plain-text file to a paginated, readable PDF.
  static Future<String> textToPdf(String txtPath) async {
    final file = File(txtPath);
    if (!file.existsSync()) {
      throw const FileNotFoundFailure(message: 'Text file not found.');
    }

    final content = await file.readAsString();
    final stem = p.basenameWithoutExtension(txtPath);
    final pdf = pw.Document();
    const fontSize = 11.0;
    const pageFormat = PdfPageFormat.a4;
    const margin = 60.0;
    final lines = content.split('\n');
    const linesPerPage = 45;

    for (var i = 0; i < lines.length; i += linesPerPage) {
      final chunk = lines.skip(i).take(linesPerPage).join('\n');
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(margin),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (i == 0)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 16),
                  child: pw.Text(
                    stem,
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              pw.Text(
                chunk,
                style: const pw.TextStyle(
                  fontSize: fontSize,
                  lineSpacing: fontSize * 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final outputPath = await FileUtils.buildOutputPath(txtPath, 'pdf');
    await File(outputPath).writeAsBytes(await pdf.save());
    MeiLogger.instance.i('TXT→PDF: $outputPath');
    return outputPath;
  }

  // ── PDF Compress ─────────────────────────────────────────────────────────────

  /// Compresses a PDF by attempting to re-encode embedded JPEG streams.
  static Future<String> compressPdf(String pdfPath, {int quality = 60}) async {
    final file = File(pdfPath);
    if (!file.existsSync()) {
      throw const FileNotFoundFailure(message: 'PDF file not found.');
    }

    final inputBytes = await file.readAsBytes();
    final outputPath = await FileUtils.buildOutputPath(pdfPath, 'pdf');

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final compressed = await FlutterImageCompress.compressWithList(
          inputBytes,
          quality: quality.clamp(1, 100),
          format: CompressFormat.jpeg,
        );
        if (compressed.length < inputBytes.length) {
          await File(outputPath).writeAsBytes(compressed);
          MeiLogger.instance.i(
            'PDF compressed: ${inputBytes.length} → ${compressed.length} bytes',
          );
          return outputPath;
        }
      } catch (_) {
        // Fallback: copy as-is
      }
    }

    await file.copy(outputPath);
    MeiLogger.instance.i('PDF compress fallback (copy): $outputPath');
    return outputPath;
  }

  // ── PDF Merge ────────────────────────────────────────────────────────────────

  /// Merges two or more PDF files into a single output PDF.
  ///
  /// Page dimensions from each source document are preserved.
  /// Heavy work runs in a background isolate.
  static Future<String> mergePdfs(List<String> pdfPaths) async {
    final validPaths = pdfPaths.where((e) => File(e).existsSync()).toList();
    if (validPaths.length < 2) {
      throw const ConversionFailure(
        message: 'Select at least 2 valid PDF files to merge.',
      );
    }

    // Load all source byte arrays
    final allBytes = <Uint8List>[];
    for (final path in validPaths) {
      allBytes.add(await File(path).readAsBytes());
    }

    // Merge in isolate so the UI stays responsive
    final mergedBytes = await compute(_mergePdfIsolate, allBytes);

    final outputPath = await FileUtils.buildOutputPath(validPaths.first, 'pdf');
    await File(outputPath).writeAsBytes(mergedBytes);
    MeiLogger.instance.i(
      'PDFs merged (${validPaths.length} files): $outputPath',
    );
    return outputPath;
  }

  // ── PDF Split ────────────────────────────────────────────────────────────────

  /// Extracts [fromPage]‥[toPage] (1-based, inclusive) from [pdfPath] into a
  /// new PDF.  Any remaining pages are written to a second output file.
  ///
  /// Returns a list of output paths:
  ///   - index 0 → extracted range
  ///   - index 1 → remainder (only present when there are pages outside the range)
  static Future<List<String>> splitPdf(
    String pdfPath, {
    required int fromPage,
    required int toPage,
  }) async {
    final file = File(pdfPath);
    if (!file.existsSync()) {
      throw const FileNotFoundFailure(message: 'PDF file not found.');
    }

    final srcBytes = await file.readAsBytes();

    // Validate page range (page count loaded separately so UI can show it)
    final pageCount = await compute(_getPageCount, srcBytes);
    if (fromPage < 1 || toPage > pageCount || fromPage > toPage) {
      throw ConversionFailure(
        message:
            'Invalid page range $fromPage–$toPage. Document has $pageCount page(s).',
      );
    }

    final args = (
      bytes: srcBytes,
      from: fromPage - 1, // convert to 0-based
      to: toPage - 1,
      total: pageCount,
    );
    final result = await compute(_splitPdfIsolate, args);

    final outputPaths = <String>[];

    final stem = p.basenameWithoutExtension(pdfPath);
    final dir  = await FileUtils.outputDir();
    final ts   = DateTime.now().millisecondsSinceEpoch;

    final extractedPath = p.join(dir.path, '${stem}_p$fromPage-${toPage}_$ts.pdf');
    await File(extractedPath).writeAsBytes(result.extracted);
    outputPaths.add(extractedPath);

    if (result.remainder != null) {
      final remainderPath = p.join(dir.path, '${stem}_remainder_$ts.pdf');
      await File(remainderPath).writeAsBytes(result.remainder!);
      outputPaths.add(remainderPath);
    }

    MeiLogger.instance.i(
      'PDF split: pages $fromPage–$toPage extracted → ${outputPaths.length} file(s)',
    );
    return outputPaths;
  }

  /// Returns the page count of a PDF without keeping it open.
  static Future<int> getPdfPageCount(String pdfPath) async {
    final bytes = await File(pdfPath).readAsBytes();
    return compute(_getPageCount, bytes);
  }
}

// ── Isolate helpers ───────────────────────────────────────────────────────────
// All functions must be top-level (no closures) so compute() can send them.

/// Merges a list of PDF byte arrays into one PDF, preserving page sizes.
List<int> _mergePdfIsolate(List<Uint8List> inputs) {
  final outputDoc = sfpdf.PdfDocument();

  for (final srcBytes in inputs) {
    sfpdf.PdfDocument? srcDoc;
    try {
      srcDoc = sfpdf.PdfDocument(inputBytes: srcBytes);
      final count = srcDoc.pages.count;
      for (int i = 0; i < count; i++) {
        final srcPage = srcDoc.pages[i];
        // Page size and margins must be set on the document before each add().
        outputDoc.pageSettings.size = srcPage.size;
        outputDoc.pageSettings.setMargins(0);
        final targetPage = outputDoc.pages.add();
        targetPage.graphics.drawPdfTemplate(
          srcPage.createTemplate(),
          Offset.zero,
        );
      }
    } finally {
      srcDoc?.dispose();
    }
  }

  final result = outputDoc.saveSync();
  outputDoc.dispose();
  return result;
}

/// Splits a PDF into an extracted range and an optional remainder.
typedef _SplitArgs = ({Uint8List bytes, int from, int to, int total});
typedef _SplitResult = ({List<int> extracted, List<int>? remainder});

_SplitResult _splitPdfIsolate(_SplitArgs args) {
  final srcDoc = sfpdf.PdfDocument(inputBytes: args.bytes);

  List<int> copyPages(Iterable<int> indices) {
    final doc = sfpdf.PdfDocument();
    for (final i in indices) {
      final srcPage = srcDoc.pages[i];
      doc.pageSettings.size = srcPage.size;
      doc.pageSettings.setMargins(0);
      final newPage = doc.pages.add();
      newPage.graphics.drawPdfTemplate(
        srcPage.createTemplate(),
        Offset.zero,
      );
    }
    final bytes = doc.saveSync();
    doc.dispose();
    return bytes;
  }

  final extractedIndices = List<int>.generate(
    args.to - args.from + 1,
    (i) => args.from + i,
  );

  final remainderIndices = [
    ...List<int>.generate(args.from, (i) => i),
    ...List<int>.generate(args.total - args.to - 1, (i) => args.to + 1 + i),
  ];

  final extracted = copyPages(extractedIndices);
  final remainder = remainderIndices.isEmpty ? null : copyPages(remainderIndices);

  srcDoc.dispose();
  return (extracted: extracted, remainder: remainder);
}

/// Returns the total page count of a PDF.
int _getPageCount(Uint8List bytes) {
  final doc = sfpdf.PdfDocument(inputBytes: bytes);
  final count = doc.pages.count;
  doc.dispose();
  return count;
}

// ── State ─────────────────────────────────────────────────────────────────────

enum PdfToolsTab { imagesToPdf, compress, mergePdfs, splitPdf }

enum PdfToolsStatus { idle, converting, done, failed }

class PdfToolsState {
  const PdfToolsState({
    this.tab = PdfToolsTab.imagesToPdf,
    this.status = PdfToolsStatus.idle,
    // — Images → PDF
    this.sourcePaths = const [],
    // — Compress
    this.pdfSourcePath,
    this.compressionQuality = 60,
    // — Merge
    this.mergePdfPaths = const [],
    // — Split
    this.splitSourcePath,
    this.splitTotalPages,
    this.splitFromPage = 1,
    this.splitToPage = 1,
    this.splitPageCountLoading = false,
    // — Output
    this.outputPath,
    this.splitOutputPaths = const [],
    this.failure,
  });

  final PdfToolsTab tab;
  final PdfToolsStatus status;

  // images → pdf
  final List<String> sourcePaths;

  // compress
  final String? pdfSourcePath;
  final int compressionQuality;

  // merge
  final List<String> mergePdfPaths;

  // split
  final String? splitSourcePath;
  final int? splitTotalPages;
  final int splitFromPage;
  final int splitToPage;
  final bool splitPageCountLoading;

  // output
  final String? outputPath;
  final List<String> splitOutputPaths;
  final MeiFailure? failure;

  // ── Computed helpers ───────────────────────────────────────────────────────
  bool get hasFiles          => sourcePaths.isNotEmpty;
  bool get hasPdf            => pdfSourcePath != null;
  bool get hasMergePdfs      => mergePdfPaths.length >= 2;
  bool get hasSplitSource    => splitSourcePath != null;
  bool get isBusy            => status == PdfToolsStatus.converting;

  bool get splitRangeValid =>
      splitTotalPages != null &&
      splitFromPage >= 1 &&
      splitToPage >= splitFromPage &&
      splitToPage <= (splitTotalPages ?? 0);

  PdfToolsState copyWith({
    PdfToolsTab? tab,
    PdfToolsStatus? status,
    List<String>? sourcePaths,
    String? pdfSourcePath,
    int? compressionQuality,
    List<String>? mergePdfPaths,
    String? splitSourcePath,
    int? splitTotalPages,
    int? splitFromPage,
    int? splitToPage,
    bool? splitPageCountLoading,
    String? outputPath,
    List<String>? splitOutputPaths,
    MeiFailure? failure,
  }) =>
      PdfToolsState(
        tab: tab ?? this.tab,
        status: status ?? this.status,
        sourcePaths: sourcePaths ?? this.sourcePaths,
        pdfSourcePath: pdfSourcePath ?? this.pdfSourcePath,
        compressionQuality: compressionQuality ?? this.compressionQuality,
        mergePdfPaths: mergePdfPaths ?? this.mergePdfPaths,
        splitSourcePath: splitSourcePath ?? this.splitSourcePath,
        splitTotalPages: splitTotalPages ?? this.splitTotalPages,
        splitFromPage: splitFromPage ?? this.splitFromPage,
        splitToPage: splitToPage ?? this.splitToPage,
        splitPageCountLoading: splitPageCountLoading ?? this.splitPageCountLoading,
        outputPath: outputPath ?? this.outputPath,
        splitOutputPaths: splitOutputPaths ?? this.splitOutputPaths,
        failure: failure ?? this.failure,
      );

  /// Returns a clean slate for the given tab (resets output + errors).
  PdfToolsState forTab(PdfToolsTab t) => PdfToolsState(tab: t);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PdfToolsNotifier extends Notifier<PdfToolsState> {
  static const _uuid = Uuid();

  @override
  PdfToolsState build() => const PdfToolsState();

  // ── Tab ───────────────────────────────────────────────────────────────────

  void setTab(PdfToolsTab tab) => state = state.forTab(tab);

  // ── Images → PDF ──────────────────────────────────────────────────────────

  void addFiles(List<String> paths) =>
      state = state.copyWith(
        sourcePaths: [...state.sourcePaths, ...paths],
        status: PdfToolsStatus.idle,
        outputPath: null,
        failure: null,
      );

  void removeFile(int index) {
    final updated = List<String>.from(state.sourcePaths)..removeAt(index);
    state = state.copyWith(sourcePaths: updated);
  }

  void reorderFiles(int oldIndex, int newIndex) {
    final updated = List<String>.from(state.sourcePaths);
    if (newIndex > oldIndex) newIndex -= 1;
    updated.insert(newIndex, updated.removeAt(oldIndex));
    state = state.copyWith(sourcePaths: updated);
  }

  void reorderFilesItem(int oldIndex, int newIndex) {
    final updated = List<String>.from(state.sourcePaths);
    updated.insert(newIndex, updated.removeAt(oldIndex));
    state = state.copyWith(sourcePaths: updated);
  }

  Future<void> convertToPdf() async {
    if (state.sourcePaths.isEmpty) return;
    state = state.copyWith(status: PdfToolsStatus.converting, failure: null);
    try {
      final out = await PdfConverterService.imagesToPdf(state.sourcePaths);
      await _saveHistory(
        inputPath: state.sourcePaths.first,
        outputPath: out,
        inputFormat: _ext(state.sourcePaths.first),
        outputFormat: 'pdf',
      );
      state = state.copyWith(status: PdfToolsStatus.done, outputPath: out);
    } catch (e) {
      state = state.copyWith(
        status: PdfToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      );
    }
  }

  // ── Compress ──────────────────────────────────────────────────────────────

  void setPdfSource(String path) =>
      state = state.copyWith(
        pdfSourcePath: path,
        status: PdfToolsStatus.idle,
        outputPath: null,
        failure: null,
      );

  void setCompressionQuality(int quality) =>
      state = state.copyWith(compressionQuality: quality);

  Future<void> compressPdf() async {
    if (state.pdfSourcePath == null) return;
    state = state.copyWith(status: PdfToolsStatus.converting, failure: null);
    try {
      final out = await PdfConverterService.compressPdf(
        state.pdfSourcePath!,
        quality: state.compressionQuality,
      );
      await _saveHistory(
        inputPath: state.pdfSourcePath!,
        outputPath: out,
        inputFormat: 'pdf',
        outputFormat: 'pdf',
      );
      state = state.copyWith(status: PdfToolsStatus.done, outputPath: out);
    } catch (e) {
      state = state.copyWith(
        status: PdfToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      );
    }
  }

  // ── Merge ─────────────────────────────────────────────────────────────────

  void addMergePdfs(List<String> paths) =>
      state = state.copyWith(
        mergePdfPaths: [...state.mergePdfPaths, ...paths],
        status: PdfToolsStatus.idle,
        outputPath: null,
        failure: null,
      );

  void removeMergePdf(int index) {
    final updated = List<String>.from(state.mergePdfPaths)..removeAt(index);
    state = state.copyWith(mergePdfPaths: updated);
  }

  void reorderMergePdf(int oldIndex, int newIndex) {
    final updated = List<String>.from(state.mergePdfPaths);
    if (newIndex > oldIndex) newIndex -= 1;
    updated.insert(newIndex, updated.removeAt(oldIndex));
    state = state.copyWith(mergePdfPaths: updated);
  }

  void reorderMergePdfItem(int oldIndex, int newIndex) {
    final updated = List<String>.from(state.mergePdfPaths);
    updated.insert(newIndex, updated.removeAt(oldIndex));
    state = state.copyWith(mergePdfPaths: updated);
  }

  Future<void> mergePdfs() async {
    if (!state.hasMergePdfs) return;
    state = state.copyWith(status: PdfToolsStatus.converting, failure: null);
    try {
      final out = await PdfConverterService.mergePdfs(state.mergePdfPaths);
      await _saveHistory(
        inputPath: state.mergePdfPaths.first,
        outputPath: out,
        inputFormat: 'pdf',
        outputFormat: 'pdf',
      );
      state = state.copyWith(status: PdfToolsStatus.done, outputPath: out);
    } catch (e) {
      state = state.copyWith(
        status: PdfToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      );
    }
  }

  // ── Split ─────────────────────────────────────────────────────────────────

  Future<void> setSplitSource(String path) async {
    state = state.copyWith(
      splitSourcePath: path,
      splitTotalPages: null,
      splitFromPage: 1,
      splitToPage: 1,
      splitPageCountLoading: true,
      status: PdfToolsStatus.idle,
      splitOutputPaths: [],
      outputPath: null,
      failure: null,
    );
    try {
      final count = await PdfConverterService.getPdfPageCount(path);
      state = state.copyWith(
        splitTotalPages: count,
        splitToPage: count,        // default: extract everything
        splitPageCountLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        splitPageCountLoading: false,
        failure: ConversionFailure(
          message: 'Could not read PDF page count: $e',
          cause: e,
        ),
      );
    }
  }

  void setSplitFromPage(int page) => state = state.copyWith(splitFromPage: page);
  void setSplitToPage(int page)   => state = state.copyWith(splitToPage: page);

  Future<void> splitPdf() async {
    if (!state.hasSplitSource || !state.splitRangeValid) return;
    state = state.copyWith(status: PdfToolsStatus.converting, failure: null);
    try {
      final outputs = await PdfConverterService.splitPdf(
        state.splitSourcePath!,
        fromPage: state.splitFromPage,
        toPage: state.splitToPage,
      );
      for (final out in outputs) {
        await _saveHistory(
          inputPath: state.splitSourcePath!,
          outputPath: out,
          inputFormat: 'pdf',
          outputFormat: 'pdf',
        );
      }
      state = state.copyWith(
        status: PdfToolsStatus.done,
        splitOutputPaths: outputs,
        outputPath: outputs.first,
      );
    } catch (e) {
      state = state.copyWith(
        status: PdfToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      );
    }
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Future<void> _saveHistory({
    required String inputPath,
    required String outputPath,
    required String inputFormat,
    required String outputFormat,
  }) async {
    try {
      final size = File(outputPath).statSync().size;
      await ref.read(historyProvider.notifier).add(
            ConversionRecord(
              id: _uuid.v4(),
              inputFileName: inputPath.split('/').last,
              inputPath: inputPath,
              outputPath: outputPath,
              inputFormat: inputFormat,
              outputFormat: outputFormat,
              fileSizeBytes: size,
              convertedAt: DateTime.now(),
              categoryName: 'pdf',
            ),
          );
    } catch (e) {
      MeiLogger.instance.w('Failed to save PDF history: $e');
    }
  }

  String _ext(String path) => path.split('.').last.toLowerCase();

  void convertAnother() {
    state = state.copyWith(
      status: PdfToolsStatus.idle,
      outputPath: null,
      splitOutputPaths: [],
      failure: null,
    );
  }

  void reset() => state = PdfToolsState(tab: state.tab);
}

final pdfToolsProvider =
    NotifierProvider<PdfToolsNotifier, PdfToolsState>(PdfToolsNotifier.new);
