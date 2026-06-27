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

enum PdfToolsTab { imagesToPdf, mergePdfs, splitPdf }

enum PdfToolsStatus { idle, converting, done, failed }

class ImagesToPdfState {
  const ImagesToPdfState({
    this.status = PdfToolsStatus.idle,
    this.sourcePaths = const [],
    this.outputPath,
    this.failure,
  });

  final PdfToolsStatus status;
  final List<String> sourcePaths;
  final String? outputPath;
  final MeiFailure? failure;

  ImagesToPdfState copyWith({
    PdfToolsStatus? status,
    List<String>? sourcePaths,
    String? outputPath,
    MeiFailure? failure,
  }) =>
      ImagesToPdfState(
        status: status ?? this.status,
        sourcePaths: sourcePaths ?? this.sourcePaths,
        outputPath: outputPath ?? this.outputPath,
        failure: failure ?? this.failure,
      );
}



class PdfMergeState {
  const PdfMergeState({
    this.status = PdfToolsStatus.idle,
    this.mergePdfPaths = const [],
    this.outputPath,
    this.failure,
  });

  final PdfToolsStatus status;
  final List<String> mergePdfPaths;
  final String? outputPath;
  final MeiFailure? failure;

  PdfMergeState copyWith({
    PdfToolsStatus? status,
    List<String>? mergePdfPaths,
    String? outputPath,
    MeiFailure? failure,
  }) =>
      PdfMergeState(
        status: status ?? this.status,
        mergePdfPaths: mergePdfPaths ?? this.mergePdfPaths,
        outputPath: outputPath ?? this.outputPath,
        failure: failure ?? this.failure,
      );
}

class PdfSplitState {
  const PdfSplitState({
    this.status = PdfToolsStatus.idle,
    this.splitSourcePath,
    this.splitTotalPages,
    this.splitFromPage = 1,
    this.splitToPage = 1,
    this.splitPageCountLoading = false,
    this.outputPath,
    this.splitOutputPaths = const [],
    this.failure,
  });

  final PdfToolsStatus status;
  final String? splitSourcePath;
  final int? splitTotalPages;
  final int splitFromPage;
  final int splitToPage;
  final bool splitPageCountLoading;
  final String? outputPath;
  final List<String> splitOutputPaths;
  final MeiFailure? failure;

  PdfSplitState copyWith({
    PdfToolsStatus? status,
    String? splitSourcePath,
    int? splitTotalPages,
    int? splitFromPage,
    int? splitToPage,
    bool? splitPageCountLoading,
    String? outputPath,
    List<String>? splitOutputPaths,
    MeiFailure? failure,
  }) =>
      PdfSplitState(
        status: status ?? this.status,
        splitSourcePath: splitSourcePath ?? this.splitSourcePath,
        splitTotalPages: splitTotalPages ?? this.splitTotalPages,
        splitFromPage: splitFromPage ?? this.splitFromPage,
        splitToPage: splitToPage ?? this.splitToPage,
        splitPageCountLoading: splitPageCountLoading ?? this.splitPageCountLoading,
        outputPath: outputPath ?? this.outputPath,
        splitOutputPaths: splitOutputPaths ?? this.splitOutputPaths,
        failure: failure ?? this.failure,
      );
}

class PdfToolsState {
  PdfToolsState({
    this.tab = PdfToolsTab.imagesToPdf,
    ImagesToPdfState? imagesToPdfState,
    PdfMergeState? mergeState,
    PdfSplitState? splitState,
    // For backward compatibility:
    PdfToolsStatus? status,
    List<String>? sourcePaths,
    List<String>? mergePdfPaths,
    String? splitSourcePath,
    int? splitTotalPages,
    int? splitFromPage,
    int? splitToPage,
    bool? splitPageCountLoading,
    String? outputPath,
    List<String>? splitOutputPaths,
    MeiFailure? failure,
  })  : imagesToPdfState = imagesToPdfState ??
            ImagesToPdfState(
              status: (tab == PdfToolsTab.imagesToPdf) ? (status ?? PdfToolsStatus.idle) : PdfToolsStatus.idle,
              sourcePaths: sourcePaths ?? const [],
              outputPath: (tab == PdfToolsTab.imagesToPdf) ? outputPath : null,
              failure: (tab == PdfToolsTab.imagesToPdf) ? failure : null,
            ),
        mergeState = mergeState ??
            PdfMergeState(
              status: (tab == PdfToolsTab.mergePdfs) ? (status ?? PdfToolsStatus.idle) : PdfToolsStatus.idle,
              mergePdfPaths: mergePdfPaths ?? const [],
              outputPath: (tab == PdfToolsTab.mergePdfs) ? outputPath : null,
              failure: (tab == PdfToolsTab.mergePdfs) ? failure : null,
            ),
        splitState = splitState ??
            PdfSplitState(
              status: (tab == PdfToolsTab.splitPdf) ? (status ?? PdfToolsStatus.idle) : PdfToolsStatus.idle,
              splitSourcePath: splitSourcePath,
              splitTotalPages: splitTotalPages,
              splitFromPage: splitFromPage ?? 1,
              splitToPage: splitToPage ?? 1,
              splitPageCountLoading: splitPageCountLoading ?? false,
              outputPath: (tab == PdfToolsTab.splitPdf) ? outputPath : null,
              splitOutputPaths: splitOutputPaths ?? const [],
              failure: (tab == PdfToolsTab.splitPdf) ? failure : null,
            );

  final PdfToolsTab tab;
  final ImagesToPdfState imagesToPdfState;
  final PdfMergeState mergeState;
  final PdfSplitState splitState;

  // Delegated getters pointing to active tab's sub-state
  PdfToolsStatus get status => switch (tab) {
        PdfToolsTab.imagesToPdf => imagesToPdfState.status,
        PdfToolsTab.mergePdfs => mergeState.status,
        PdfToolsTab.splitPdf => splitState.status,
      };

  String? get outputPath => switch (tab) {
        PdfToolsTab.imagesToPdf => imagesToPdfState.outputPath,
        PdfToolsTab.mergePdfs => mergeState.outputPath,
        PdfToolsTab.splitPdf => splitState.outputPath,
      };

  MeiFailure? get failure => switch (tab) {
        PdfToolsTab.imagesToPdf => imagesToPdfState.failure,
        PdfToolsTab.mergePdfs => mergeState.failure,
        PdfToolsTab.splitPdf => splitState.failure,
      };

  List<String> get sourcePaths => imagesToPdfState.sourcePaths;
  List<String> get mergePdfPaths => mergeState.mergePdfPaths;
  String? get splitSourcePath => splitState.splitSourcePath;
  int? get splitTotalPages => splitState.splitTotalPages;
  int get splitFromPage => splitState.splitFromPage;
  int get splitToPage => splitState.splitToPage;
  bool get splitPageCountLoading => splitState.splitPageCountLoading;
  List<String> get splitOutputPaths => splitState.splitOutputPaths;

  // Computed helpers
  bool get hasFiles          => sourcePaths.isNotEmpty;
  bool get hasMergePdfs      => mergePdfPaths.length >= 2;
  bool get hasSplitSource    => splitSourcePath != null;
  bool get isBusy            => status == PdfToolsStatus.converting;

  bool get splitRangeValid =>
      splitTotalPages != null &&
      splitFromPage >= 1 &&
      splitToPage >= splitFromPage &&
      splitToPage <= (splitTotalPages ?? 0);

  /// Returns a clean slate for the given tab (resets output + errors).
  PdfToolsState forTab(PdfToolsTab t) => PdfToolsState(tab: t);

  PdfToolsState copyWith({
    PdfToolsTab? tab,
    ImagesToPdfState? imagesToPdfState,
    PdfMergeState? mergeState,
    PdfSplitState? splitState,
    // Backward compatibility:
    PdfToolsStatus? status,
    List<String>? sourcePaths,
    List<String>? mergePdfPaths,
    String? splitSourcePath,
    int? splitTotalPages,
    int? splitFromPage,
    int? splitToPage,
    bool? splitPageCountLoading,
    String? outputPath,
    List<String>? splitOutputPaths,
    MeiFailure? failure,
  }) {
    final nextTab = tab ?? this.tab;
    return PdfToolsState(
      tab: nextTab,
      imagesToPdfState: imagesToPdfState ??
          this.imagesToPdfState.copyWith(
            status: (nextTab == PdfToolsTab.imagesToPdf) ? (status ?? this.imagesToPdfState.status) : this.imagesToPdfState.status,
            sourcePaths: sourcePaths ?? this.imagesToPdfState.sourcePaths,
            outputPath: (nextTab == PdfToolsTab.imagesToPdf) ? (outputPath ?? this.imagesToPdfState.outputPath) : this.imagesToPdfState.outputPath,
            failure: (nextTab == PdfToolsTab.imagesToPdf) ? (failure ?? this.imagesToPdfState.failure) : this.imagesToPdfState.failure,
          ),
      mergeState: mergeState ??
          this.mergeState.copyWith(
            status: (nextTab == PdfToolsTab.mergePdfs) ? (status ?? this.mergeState.status) : this.mergeState.status,
            mergePdfPaths: mergePdfPaths ?? this.mergeState.mergePdfPaths,
            outputPath: (nextTab == PdfToolsTab.mergePdfs) ? (outputPath ?? this.mergeState.outputPath) : this.mergeState.outputPath,
            failure: (nextTab == PdfToolsTab.mergePdfs) ? (failure ?? this.mergeState.failure) : this.mergeState.failure,
          ),
      splitState: splitState ??
          this.splitState.copyWith(
            status: (nextTab == PdfToolsTab.splitPdf) ? (status ?? this.splitState.status) : this.splitState.status,
            splitSourcePath: splitSourcePath ?? this.splitState.splitSourcePath,
            splitTotalPages: splitTotalPages ?? this.splitState.splitTotalPages,
            splitFromPage: splitFromPage ?? this.splitState.splitFromPage,
            splitToPage: splitToPage ?? this.splitState.splitToPage,
            splitPageCountLoading: splitPageCountLoading ?? this.splitPageCountLoading,
            outputPath: (nextTab == PdfToolsTab.splitPdf) ? (outputPath ?? this.splitState.outputPath) : this.splitState.outputPath,
            splitOutputPaths: splitOutputPaths ?? this.splitOutputPaths,
            failure: (nextTab == PdfToolsTab.splitPdf) ? (failure ?? this.splitState.failure) : this.splitState.failure,
          ),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class PdfToolsNotifier extends Notifier<PdfToolsState> {
  static const _uuid = Uuid();

  @override
  PdfToolsState build() => PdfToolsState();

  // Helper updates for sub-states
  void _updateImagesToPdf(ImagesToPdfState Function(ImagesToPdfState) update) {
    state = state.copyWith(imagesToPdfState: update(state.imagesToPdfState));
  }

  void _updateMerge(PdfMergeState Function(PdfMergeState) update) {
    state = state.copyWith(mergeState: update(state.mergeState));
  }

  void _updateSplit(PdfSplitState Function(PdfSplitState) update) {
    state = state.copyWith(splitState: update(state.splitState));
  }

  // ── Tab ───────────────────────────────────────────────────────────────────

  void setTab(PdfToolsTab tab) => state = state.copyWith(tab: tab);

  // ── Images → PDF ──────────────────────────────────────────────────────────

  void addFiles(List<String> paths) =>
      _updateImagesToPdf((s) => s.copyWith(
        sourcePaths: [...s.sourcePaths, ...paths],
        status: PdfToolsStatus.idle,
        outputPath: null,
        failure: null,
      ));

  void removeFile(int index) {
    _updateImagesToPdf((s) {
      final updated = List<String>.from(s.sourcePaths)..removeAt(index);
      return s.copyWith(sourcePaths: updated);
    });
  }

  void reorderFiles(int oldIndex, int newIndex) {
    _updateImagesToPdf((s) {
      final updated = List<String>.from(s.sourcePaths);
      if (newIndex > oldIndex) newIndex -= 1;
      updated.insert(newIndex, updated.removeAt(oldIndex));
      return s.copyWith(sourcePaths: updated);
    });
  }

  void reorderFilesItem(int oldIndex, int newIndex) {
    _updateImagesToPdf((s) {
      final updated = List<String>.from(s.sourcePaths);
      updated.insert(newIndex, updated.removeAt(oldIndex));
      return s.copyWith(sourcePaths: updated);
    });
  }

  Future<void> convertToPdf() async {
    if (state.sourcePaths.isEmpty) return;
    _updateImagesToPdf((s) => s.copyWith(status: PdfToolsStatus.converting, failure: null));
    try {
      var out = await PdfConverterService.imagesToPdf(state.sourcePaths);
      out = await FileUtils.moveToPublic(out);
      await _saveHistory(
        inputPath: state.sourcePaths.first,
        outputPath: out,
        inputFormat: _ext(state.sourcePaths.first),
        outputFormat: 'pdf',
      );
      _updateImagesToPdf((s) => s.copyWith(status: PdfToolsStatus.done, outputPath: out));
    } catch (e) {
      _updateImagesToPdf((s) => s.copyWith(
        status: PdfToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      ));
    }
  }



  // ── Merge ─────────────────────────────────────────────────────────────────

  void addMergePdfs(List<String> paths) =>
      _updateMerge((s) => s.copyWith(
        mergePdfPaths: [...s.mergePdfPaths, ...paths],
        status: PdfToolsStatus.idle,
        outputPath: null,
        failure: null,
      ));

  void removeMergePdf(int index) {
    _updateMerge((s) {
      final updated = List<String>.from(s.mergePdfPaths)..removeAt(index);
      return s.copyWith(mergePdfPaths: updated);
    });
  }

  void reorderMergePdf(int oldIndex, int newIndex) {
    _updateMerge((s) {
      final updated = List<String>.from(s.mergePdfPaths);
      if (newIndex > oldIndex) newIndex -= 1;
      updated.insert(newIndex, updated.removeAt(oldIndex));
      return s.copyWith(mergePdfPaths: updated);
    });
  }

  void reorderMergePdfItem(int oldIndex, int newIndex) {
    _updateMerge((s) {
      final updated = List<String>.from(s.mergePdfPaths);
      updated.insert(newIndex, updated.removeAt(oldIndex));
      return s.copyWith(mergePdfPaths: updated);
    });
  }

  Future<void> mergePdfs() async {
    if (!state.hasMergePdfs) return;
    _updateMerge((s) => s.copyWith(status: PdfToolsStatus.converting, failure: null));
    try {
      var out = await PdfConverterService.mergePdfs(state.mergePdfPaths);
      out = await FileUtils.moveToPublic(out);
      await _saveHistory(
        inputPath: state.mergePdfPaths.first,
        outputPath: out,
        inputFormat: 'pdf',
        outputFormat: 'pdf',
      );
      _updateMerge((s) => s.copyWith(status: PdfToolsStatus.done, outputPath: out));
    } catch (e) {
      _updateMerge((s) => s.copyWith(
        status: PdfToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      ));
    }
  }

  // ── Split ─────────────────────────────────────────────────────────────────

  Future<void> setSplitSource(String path) async {
    _updateSplit((s) => s.copyWith(
      splitSourcePath: path,
      splitTotalPages: null,
      splitFromPage: 1,
      splitToPage: 1,
      splitPageCountLoading: true,
      status: PdfToolsStatus.idle,
      splitOutputPaths: [],
      outputPath: null,
      failure: null,
    ));
    try {
      final count = await PdfConverterService.getPdfPageCount(path);
      _updateSplit((s) => s.copyWith(
        splitTotalPages: count,
        splitToPage: count,        // default: extract everything
        splitPageCountLoading: false,
      ));
    } catch (e) {
      _updateSplit((s) => s.copyWith(
        splitPageCountLoading: false,
        failure: ConversionFailure(
          message: 'Could not read PDF page count: $e',
          cause: e,
        ),
      ));
    }
  }

  void setSplitFromPage(int page) => _updateSplit((s) => s.copyWith(splitFromPage: page));
  void setSplitToPage(int page)   => _updateSplit((s) => s.copyWith(splitToPage: page));

  Future<void> splitPdf() async {
    if (!state.hasSplitSource || !state.splitRangeValid) return;
    _updateSplit((s) => s.copyWith(status: PdfToolsStatus.converting, failure: null));
    try {
      final outputs = await PdfConverterService.splitPdf(
        state.splitSourcePath!,
        fromPage: state.splitFromPage,
        toPage: state.splitToPage,
      );
      final publicOutputs = <String>[];
      for (final out in outputs) {
        final pub = await FileUtils.moveToPublic(out);
        publicOutputs.add(pub);
        await _saveHistory(
          inputPath: state.splitSourcePath!,
          outputPath: pub,
          inputFormat: 'pdf',
          outputFormat: 'pdf',
        );
      }
      _updateSplit((s) => s.copyWith(
        status: PdfToolsStatus.done,
        splitOutputPaths: publicOutputs,
        outputPath: publicOutputs.first,
      ));
    } catch (e) {
      _updateSplit((s) => s.copyWith(
        status: PdfToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      ));
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
    switch (state.tab) {
      case PdfToolsTab.imagesToPdf:
        _updateImagesToPdf((s) => s.copyWith(status: PdfToolsStatus.idle, outputPath: null, failure: null));
      case PdfToolsTab.mergePdfs:
        _updateMerge((s) => s.copyWith(status: PdfToolsStatus.idle, outputPath: null, failure: null));
      case PdfToolsTab.splitPdf:
        _updateSplit((s) => s.copyWith(status: PdfToolsStatus.idle, outputPath: null, splitOutputPaths: [], failure: null));
    }
  }

  void reset() {
    switch (state.tab) {
      case PdfToolsTab.imagesToPdf:
        _updateImagesToPdf((s) => const ImagesToPdfState());
      case PdfToolsTab.mergePdfs:
        _updateMerge((s) => const PdfMergeState());
      case PdfToolsTab.splitPdf:
        _updateSplit((s) => const PdfSplitState());
    }
  }

  void debugUpdateState(PdfToolsState Function(PdfToolsState) update) {
    state = update(state);
  }
}

final pdfToolsProvider =
    NotifierProvider<PdfToolsNotifier, PdfToolsState>(PdfToolsNotifier.new);
