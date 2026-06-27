import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../core/models/conversion_record.dart';
import '../../../core/services/mei_logger.dart';
import '../../../core/utils/file_utils.dart';
import '../../pdf_tools/services/pdf_converter_service.dart';
import '../../recent_files/providers/history_provider.dart';
import '../services/document_converter_service.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum DocumentsTab { toPdf, toDocx }

enum DocumentsStatus { idle, converting, done, failed }

// ── State ─────────────────────────────────────────────────────────────────────

class DocumentsTabState {
  const DocumentsTabState({
    this.status = DocumentsStatus.idle,
    this.selectedPath,
    this.previewLines = const [],
    this.outputPath,
    this.failure,
  });

  final DocumentsStatus status;
  final String? selectedPath;
  final List<String> previewLines;
  final String? outputPath;
  final MeiFailure? failure;

  DocumentsTabState copyWith({
    DocumentsStatus? status,
    String? selectedPath,
    List<String>? previewLines,
    String? outputPath,
    MeiFailure? failure,
  }) =>
      DocumentsTabState(
        status: status ?? this.status,
        selectedPath: selectedPath ?? this.selectedPath,
        previewLines: previewLines ?? this.previewLines,
        outputPath: outputPath ?? this.outputPath,
        failure: failure ?? this.failure,
      );
}

class DocumentsState {
  DocumentsState({
    this.tab = DocumentsTab.toPdf,
    DocumentsTabState? pdfState,
    DocumentsTabState? docxState,
    // Backward compatibility:
    DocumentsStatus? status,
    String? selectedPath,
    List<String>? previewLines,
    String? outputPath,
    MeiFailure? failure,
  })  : pdfState = pdfState ??
            DocumentsTabState(
              status: (tab == DocumentsTab.toPdf) ? (status ?? DocumentsStatus.idle) : DocumentsStatus.idle,
              selectedPath: (tab == DocumentsTab.toPdf) ? selectedPath : null,
              previewLines: (tab == DocumentsTab.toPdf) ? (previewLines ?? const []) : const [],
              outputPath: (tab == DocumentsTab.toPdf) ? outputPath : null,
              failure: (tab == DocumentsTab.toPdf) ? failure : null,
            ),
        docxState = docxState ??
            DocumentsTabState(
              status: (tab == DocumentsTab.toDocx) ? (status ?? DocumentsStatus.idle) : DocumentsStatus.idle,
              selectedPath: (tab == DocumentsTab.toDocx) ? selectedPath : null,
              previewLines: (tab == DocumentsTab.toDocx) ? (previewLines ?? const []) : const [],
              outputPath: (tab == DocumentsTab.toDocx) ? outputPath : null,
              failure: (tab == DocumentsTab.toDocx) ? failure : null,
            );

  final DocumentsTab tab;
  final DocumentsTabState pdfState;
  final DocumentsTabState docxState;

  DocumentsTabState get currentTabState => tab == DocumentsTab.toPdf ? pdfState : docxState;

  // Computed properties pointing to the active tab's sub-state
  DocumentsStatus get status => currentTabState.status;
  String? get selectedPath => currentTabState.selectedPath;
  List<String> get previewLines => currentTabState.previewLines;
  String? get outputPath => currentTabState.outputPath;
  MeiFailure? get failure => currentTabState.failure;

  bool get hasFile => selectedPath != null;
  bool get isBusy  => status == DocumentsStatus.converting;
  String get fileName =>
      selectedPath != null ? selectedPath!.split('/').last : '';

  DocumentsState copyWith({
    DocumentsTab? tab,
    DocumentsTabState? pdfState,
    DocumentsTabState? docxState,
    // Backward compatibility:
    DocumentsStatus? status,
    String? selectedPath,
    List<String>? previewLines,
    String? outputPath,
    MeiFailure? failure,
  }) {
    final nextTab = tab ?? this.tab;
    return DocumentsState(
      tab: nextTab,
      pdfState: pdfState ??
          this.pdfState.copyWith(
            status: (nextTab == DocumentsTab.toPdf) ? (status ?? this.pdfState.status) : this.pdfState.status,
            selectedPath: (nextTab == DocumentsTab.toPdf) ? (selectedPath ?? this.pdfState.selectedPath) : this.pdfState.selectedPath,
            previewLines: (nextTab == DocumentsTab.toPdf) ? (previewLines ?? this.pdfState.previewLines) : this.pdfState.previewLines,
            outputPath: (nextTab == DocumentsTab.toPdf) ? (outputPath ?? this.pdfState.outputPath) : this.pdfState.outputPath,
            failure: (nextTab == DocumentsTab.toPdf) ? (failure ?? this.pdfState.failure) : this.pdfState.failure,
          ),
      docxState: docxState ??
          this.docxState.copyWith(
            status: (nextTab == DocumentsTab.toDocx) ? (status ?? this.docxState.status) : this.docxState.status,
            selectedPath: (nextTab == DocumentsTab.toDocx) ? (selectedPath ?? this.docxState.selectedPath) : this.docxState.selectedPath,
            previewLines: (nextTab == DocumentsTab.toDocx) ? (previewLines ?? this.docxState.previewLines) : this.docxState.previewLines,
            outputPath: (nextTab == DocumentsTab.toDocx) ? (outputPath ?? this.docxState.outputPath) : this.docxState.outputPath,
            failure: (nextTab == DocumentsTab.toDocx) ? (failure ?? this.docxState.failure) : this.docxState.failure,
          ),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DocumentsNotifier extends Notifier<DocumentsState> {
  static final _log = MeiLogger.instance;
  static const _uuid = Uuid();

  @override
  DocumentsState build() => DocumentsState();

  // Helper to update active tab's sub-state
  void _updateCurrentTab(DocumentsTabState Function(DocumentsTabState) update) {
    if (state.tab == DocumentsTab.toPdf) {
      state = state.copyWith(pdfState: update(state.pdfState));
    } else {
      state = state.copyWith(docxState: update(state.docxState));
    }
  }

  // ── Tab ───────────────────────────────────────────────────────────────────

  void setTab(DocumentsTab tab) {
    state = state.copyWith(tab: tab);
  }

  // ── File picking ──────────────────────────────────────────────────────────

  Future<void> pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['txt', 'md'],
        allowMultiple: false,
      );
      if (result == null || result.paths.isEmpty) return;
      final path = result.paths.first;
      if (path == null) return;

      final content = await File(path).readAsString();
      final lines   = content.split('\n').take(20).toList();

      _updateCurrentTab((s) => s.copyWith(
        selectedPath: path,
        previewLines: lines,
        status: DocumentsStatus.idle,
        outputPath: null,
        failure: null,
      ));
    } catch (e, st) {
      _log.e('pickFile failed', e, st);
    }
  }

  // ── Conversions ───────────────────────────────────────────────────────────

  /// TXT → PDF using the pw (pdf) package.
  Future<void> convertToPdf() async {
    if (!state.hasFile) return;
    _updateCurrentTab((s) => s.copyWith(status: DocumentsStatus.converting, failure: null));
    try {
      var out = await PdfConverterService.textToPdf(state.selectedPath!);
      out = await FileUtils.moveToPublic(out);
      await _saveHistory(
        inputPath: state.selectedPath!,
        outputPath: out,
        inputFormat: _ext(state.selectedPath!),
        outputFormat: 'pdf',
      );
      _updateCurrentTab((s) => s.copyWith(status: DocumentsStatus.done, outputPath: out));
    } catch (e, st) {
      _log.e('convertToPdf failed', e, st);
      _updateCurrentTab((s) => s.copyWith(
        status: DocumentsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      ));
    }
  }

  /// TXT → DOCX using the pure-Dart OpenXML builder.
  Future<void> convertToDocx() async {
    if (!state.hasFile) return;
    _updateCurrentTab((s) => s.copyWith(status: DocumentsStatus.converting, failure: null));
    try {
      var out =
          await DocumentConverterService.convertToDocx(state.selectedPath!);
      out = await FileUtils.moveToPublic(out);
      await _saveHistory(
        inputPath: state.selectedPath!,
        outputPath: out,
        inputFormat: _ext(state.selectedPath!),
        outputFormat: 'docx',
      );
      _updateCurrentTab((s) => s.copyWith(status: DocumentsStatus.done, outputPath: out));
    } catch (e, st) {
      _log.e('convertToDocx failed', e, st);
      _updateCurrentTab((s) => s.copyWith(
        status: DocumentsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      ));
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void convertAnother() {
    _updateCurrentTab((s) => s.copyWith(
      status: DocumentsStatus.idle,
      outputPath: null,
      failure: null,
    ));
  }

  void reset() {
    _updateCurrentTab((s) => const DocumentsTabState());
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _saveHistory({
    required String inputPath,
    required String outputPath,
    required String inputFormat,
    required String outputFormat,
  }) async {
    try {
      final size = File(outputPath).statSync().size;
      final record = ConversionRecord(
        id: _uuid.v4(),
        inputFileName: inputPath.split('/').last,
        inputPath: inputPath,
        outputPath: outputPath,
        inputFormat: inputFormat,
        outputFormat: outputFormat,
        fileSizeBytes: size,
        convertedAt: DateTime.now(),
        categoryName: 'document',
      );
      await ref.read(historyProvider.notifier).add(record);
    } catch (e) {
      _log.w('Failed to save document history: $e');
    }
  }

  String _ext(String path) => path.split('.').last.toLowerCase();

  void debugUpdateState(DocumentsState Function(DocumentsState) update) {
    state = update(state);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final documentsProvider =
    NotifierProvider<DocumentsNotifier, DocumentsState>(DocumentsNotifier.new);
