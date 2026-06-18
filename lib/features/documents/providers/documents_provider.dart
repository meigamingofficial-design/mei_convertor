import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../core/models/conversion_record.dart';
import '../../../core/services/mei_logger.dart';
import '../../pdf_tools/services/pdf_converter_service.dart';
import '../../recent_files/providers/history_provider.dart';
import '../services/document_converter_service.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum DocumentsTab { toPdf, toDocx }

enum DocumentsStatus { idle, converting, done, failed }

// ── State ─────────────────────────────────────────────────────────────────────

class DocumentsState {
  const DocumentsState({
    this.tab = DocumentsTab.toPdf,
    this.status = DocumentsStatus.idle,
    this.selectedPath,
    this.previewLines = const [],
    this.outputPath,
    this.failure,
  });

  final DocumentsTab tab;
  final DocumentsStatus status;
  final String? selectedPath;
  final List<String> previewLines;
  final String? outputPath;
  final MeiFailure? failure;

  // ── Computed ──────────────────────────────────────────────────────────────
  bool get hasFile => selectedPath != null;
  bool get isBusy  => status == DocumentsStatus.converting;
  String get fileName =>
      selectedPath != null ? selectedPath!.split('/').last : '';

  DocumentsState copyWith({
    DocumentsTab? tab,
    DocumentsStatus? status,
    String? selectedPath,
    List<String>? previewLines,
    String? outputPath,
    MeiFailure? failure,
  }) =>
      DocumentsState(
        tab: tab ?? this.tab,
        status: status ?? this.status,
        selectedPath: selectedPath ?? this.selectedPath,
        previewLines: previewLines ?? this.previewLines,
        outputPath: outputPath ?? this.outputPath,
        failure: failure ?? this.failure,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class DocumentsNotifier extends Notifier<DocumentsState> {
  static final _log = MeiLogger.instance;
  static const _uuid = Uuid();

  @override
  DocumentsState build() => const DocumentsState();

  // ── Tab ───────────────────────────────────────────────────────────────────

  void setTab(DocumentsTab tab) {
    // Switching tabs resets the whole state so output/errors from the
    // previous tab don't bleed through.
    state = DocumentsState(tab: tab);
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

      state = DocumentsState(
        tab: state.tab,
        selectedPath: path,
        previewLines: lines,
      );
    } catch (e, st) {
      _log.e('pickFile failed', e, st);
    }
  }

  // ── Conversions ───────────────────────────────────────────────────────────

  /// TXT → PDF using the pw (pdf) package.
  Future<void> convertToPdf() async {
    if (!state.hasFile) return;
    state = state.copyWith(status: DocumentsStatus.converting, failure: null);
    try {
      final out = await PdfConverterService.textToPdf(state.selectedPath!);
      await _saveHistory(
        inputPath: state.selectedPath!,
        outputPath: out,
        inputFormat: _ext(state.selectedPath!),
        outputFormat: 'pdf',
      );
      state = state.copyWith(status: DocumentsStatus.done, outputPath: out);
    } catch (e, st) {
      _log.e('convertToPdf failed', e, st);
      state = state.copyWith(
        status: DocumentsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      );
    }
  }

  /// TXT → DOCX using the pure-Dart OpenXML builder.
  Future<void> convertToDocx() async {
    if (!state.hasFile) return;
    state = state.copyWith(status: DocumentsStatus.converting, failure: null);
    try {
      final out =
          await DocumentConverterService.convertToDocx(state.selectedPath!);
      await _saveHistory(
        inputPath: state.selectedPath!,
        outputPath: out,
        inputFormat: _ext(state.selectedPath!),
        outputFormat: 'docx',
      );
      state = state.copyWith(status: DocumentsStatus.done, outputPath: out);
    } catch (e, st) {
      _log.e('convertToDocx failed', e, st);
      state = state.copyWith(
        status: DocumentsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      );
    }
  }

  // ── Reset ─────────────────────────────────────────────────────────────────

  void convertAnother() {
    state = state.copyWith(
      status: DocumentsStatus.idle,
      outputPath: null,
      failure: null,
    );
  }

  void reset() => state = DocumentsState(tab: state.tab);

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
}

// ── Provider ──────────────────────────────────────────────────────────────────

final documentsProvider =
    NotifierProvider<DocumentsNotifier, DocumentsState>(DocumentsNotifier.new);
