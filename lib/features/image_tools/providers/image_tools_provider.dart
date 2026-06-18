import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../core/models/conversion_record.dart';
import '../../../core/services/mei_logger.dart';
import '../../recent_files/providers/history_provider.dart';
import '../services/image_converter_service.dart';

// ── Enums & Sub-state ─────────────────────────────────────────────────────────

enum ImageToolsTab { convert, compress, resize }

enum ImageToolsStatus { idle, converting, done, failed }

class ImageToolsState {
  const ImageToolsState({
    this.tab = ImageToolsTab.convert,
    this.status = ImageToolsStatus.idle,
    this.selectedPaths = const [],
    this.outputFormat = 'png',
    this.quality = 80,
    this.targetWidth,
    this.targetHeight,
    this.lockAspectRatio = true,
    this.sourceWidth,
    this.sourceHeight,
    this.outputPath,
    this.failure,
    this.progress = 0.0,
  });

  final ImageToolsTab tab;
  final ImageToolsStatus status;
  final List<String> selectedPaths;
  final String outputFormat;
  final int quality;
  final int? targetWidth;
  final int? targetHeight;
  final bool lockAspectRatio;
  final int? sourceWidth;
  final int? sourceHeight;
  final String? outputPath;
  final MeiFailure? failure;
  final double progress;

  bool get hasFile => selectedPaths.isNotEmpty;
  bool get isBusy => status == ImageToolsStatus.converting;
  String get primaryPath => selectedPaths.isEmpty ? '' : selectedPaths.first;

  ImageToolsState copyWith({
    ImageToolsTab? tab,
    ImageToolsStatus? status,
    List<String>? selectedPaths,
    String? outputFormat,
    int? quality,
    int? targetWidth,
    int? targetHeight,
    bool? lockAspectRatio,
    int? sourceWidth,
    int? sourceHeight,
    String? outputPath,
    MeiFailure? failure,
    double? progress,
  }) =>
      ImageToolsState(
        tab: tab ?? this.tab,
        status: status ?? this.status,
        selectedPaths: selectedPaths ?? this.selectedPaths,
        outputFormat: outputFormat ?? this.outputFormat,
        quality: quality ?? this.quality,
        targetWidth: targetWidth ?? this.targetWidth,
        targetHeight: targetHeight ?? this.targetHeight,
        lockAspectRatio: lockAspectRatio ?? this.lockAspectRatio,
        sourceWidth: sourceWidth ?? this.sourceWidth,
        sourceHeight: sourceHeight ?? this.sourceHeight,
        outputPath: outputPath ?? this.outputPath,
        failure: failure ?? this.failure,
        progress: progress ?? this.progress,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ImageToolsNotifier extends Notifier<ImageToolsState> {
  static final _log = MeiLogger.instance;
  static const _uuid = Uuid();

  @override
  ImageToolsState build() => const ImageToolsState();

  void setTab(ImageToolsTab tab) =>
      state = state.copyWith(tab: tab, status: ImageToolsStatus.idle);

  void setOutputFormat(String fmt) => state = state.copyWith(outputFormat: fmt);

  void setQuality(int quality) => state = state.copyWith(quality: quality);

  void setTargetWidth(int? w) {
    if (state.lockAspectRatio &&
        w != null &&
        state.sourceWidth != null &&
        state.sourceHeight != null) {
      final ratio = state.sourceHeight! / state.sourceWidth!;
      state = state.copyWith(targetWidth: w, targetHeight: (w * ratio).round());
    } else {
      state = state.copyWith(targetWidth: w);
    }
  }

  void setTargetHeight(int? h) {
    if (state.lockAspectRatio &&
        h != null &&
        state.sourceWidth != null &&
        state.sourceHeight != null) {
      final ratio = state.sourceWidth! / state.sourceHeight!;
      state =
          state.copyWith(targetHeight: h, targetWidth: (h * ratio).round());
    } else {
      state = state.copyWith(targetHeight: h);
    }
  }

  void toggleAspectLock() {
    final nextLock = !state.lockAspectRatio;
    if (nextLock &&
        state.targetWidth != null &&
        state.sourceWidth != null &&
        state.sourceHeight != null) {
      final ratio = state.sourceHeight! / state.sourceWidth!;
      state = state.copyWith(
        lockAspectRatio: nextLock,
        targetHeight: (state.targetWidth! * ratio).round(),
      );
    } else {
      state = state.copyWith(lockAspectRatio: nextLock);
    }
  }

  Future<void> pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: state.tab == ImageToolsTab.convert,
      );
      if (result == null) return;
      final paths = result.paths.whereType<String>().toList();
      if (paths.isEmpty) return;
      state = state.copyWith(
        selectedPaths: paths,
        outputPath: null,
        failure: null,
        status: ImageToolsStatus.idle,
      );
      if (state.tab == ImageToolsTab.resize) unawaited(_loadDimensions(paths.first));
    } catch (e, st) {
      _log.e('pickFiles failed', e, st);
    }
  }

  Future<void> _loadDimensions(String path) async {
    try {
      final dim = await ImageConverterService.getDimensions(path);
      state = state.copyWith(
        sourceWidth: dim.width,
        sourceHeight: dim.height,
        targetWidth: dim.width,
        targetHeight: dim.height,
      );
    } catch (_) {}
  }

  Future<void> convert() async {
    if (!state.hasFile) return;
    state = state.copyWith(status: ImageToolsStatus.converting, failure: null);
    try {
      final paths = state.selectedPaths;
      String lastOutput = '';
      for (var i = 0; i < paths.length; i++) {
        state = state.copyWith(progress: i / paths.length);
        lastOutput = await ImageConverterService.convert(paths[i], state.outputFormat);
        await _saveToHistory(
          inputPath: paths[i],
          outputPath: lastOutput,
          inputFormat: _ext(paths[i]),
          outputFormat: state.outputFormat,
          category: 'image',
        );
      }
      state = state.copyWith(
        status: ImageToolsStatus.done,
        outputPath: lastOutput,
        progress: 1.0,
      );
    } catch (e, st) {
      _log.e('convert failed', e, st);
      state = state.copyWith(
        status: ImageToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      );
    }
  }

  Future<void> compress() async {
    if (!state.hasFile) return;
    state = state.copyWith(status: ImageToolsStatus.converting, failure: null);
    try {
      final out = await ImageConverterService.compress(state.primaryPath,
          quality: state.quality);
      await _saveToHistory(
        inputPath: state.primaryPath,
        outputPath: out,
        inputFormat: _ext(state.primaryPath),
        outputFormat: 'jpg',
        category: 'image',
      );
      state = state.copyWith(status: ImageToolsStatus.done, outputPath: out);
    } catch (e, st) {
      _log.e('compress failed', e, st);
      state = state.copyWith(
        status: ImageToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      );
    }
  }

  Future<void> resize() async {
    if (!state.hasFile) return;
    state = state.copyWith(status: ImageToolsStatus.converting, failure: null);
    try {
      final out = await ImageConverterService.resize(
        state.primaryPath,
        targetWidth: state.targetWidth,
        targetHeight: state.targetHeight,
      );
      await _saveToHistory(
        inputPath: state.primaryPath,
        outputPath: out,
        inputFormat: _ext(state.primaryPath),
        outputFormat: _ext(out),
        category: 'image',
      );
      state = state.copyWith(status: ImageToolsStatus.done, outputPath: out);
    } catch (e, st) {
      _log.e('resize failed', e, st);
      state = state.copyWith(
        status: ImageToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      );
    }
  }

  Future<void> _saveToHistory({
    required String inputPath,
    required String outputPath,
    required String inputFormat,
    required String outputFormat,
    required String category,
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
        categoryName: category,
      );
      await ref.read(historyProvider.notifier).add(record);
    } catch (e) {
      _log.w('Failed to save history record: $e');
    }
  }

  void convertAnother() {
    state = state.copyWith(
      status: ImageToolsStatus.idle,
      outputPath: null,
      failure: null,
      progress: 0.0,
    );
  }

  void reset() => state = ImageToolsState(tab: state.tab);

  String _ext(String path) => path.split('.').last.toLowerCase();
}

final imageToolsProvider =
    NotifierProvider<ImageToolsNotifier, ImageToolsState>(
  ImageToolsNotifier.new,
);
