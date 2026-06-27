import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/failures.dart';
import '../../../core/models/conversion_record.dart';
import '../../../core/services/mei_logger.dart';
import '../../../core/utils/file_utils.dart';
import '../../recent_files/providers/history_provider.dart';
import '../services/image_converter_service.dart';

// ── Enums & Sub-state ─────────────────────────────────────────────────────────

enum ImageToolsTab { convert, compress, resize }

enum ImageToolsStatus { idle, converting, done, failed }

class ImageConvertState {
  const ImageConvertState({
    this.status = ImageToolsStatus.idle,
    this.selectedPaths = const [],
    this.outputFormat = 'png',
    this.outputPath,
    this.failure,
    this.progress = 0.0,
  });

  final ImageToolsStatus status;
  final List<String> selectedPaths;
  final String outputFormat;
  final String? outputPath;
  final MeiFailure? failure;
  final double progress;

  ImageConvertState copyWith({
    ImageToolsStatus? status,
    List<String>? selectedPaths,
    String? outputFormat,
    String? outputPath,
    MeiFailure? failure,
    double? progress,
  }) =>
      ImageConvertState(
        status: status ?? this.status,
        selectedPaths: selectedPaths ?? this.selectedPaths,
        outputFormat: outputFormat ?? this.outputFormat,
        outputPath: outputPath ?? this.outputPath,
        failure: failure ?? this.failure,
        progress: progress ?? this.progress,
      );
}

class ImageCompressState {
  const ImageCompressState({
    this.status = ImageToolsStatus.idle,
    this.selectedPaths = const [],
    this.quality = 80,
    this.outputPath,
    this.failure,
  });

  final ImageToolsStatus status;
  final List<String> selectedPaths;
  final int quality;
  final String? outputPath;
  final MeiFailure? failure;

  ImageCompressState copyWith({
    ImageToolsStatus? status,
    List<String>? selectedPaths,
    int? quality,
    String? outputPath,
    MeiFailure? failure,
  }) =>
      ImageCompressState(
        status: status ?? this.status,
        selectedPaths: selectedPaths ?? this.selectedPaths,
        quality: quality ?? this.quality,
        outputPath: outputPath ?? this.outputPath,
        failure: failure ?? this.failure,
      );
}

class ImageResizeState {
  const ImageResizeState({
    this.status = ImageToolsStatus.idle,
    this.selectedPaths = const [],
    this.targetWidth,
    this.targetHeight,
    this.lockAspectRatio = true,
    this.sourceWidth,
    this.sourceHeight,
    this.outputPath,
    this.failure,
  });

  final ImageToolsStatus status;
  final List<String> selectedPaths;
  final int? targetWidth;
  final int? targetHeight;
  final bool lockAspectRatio;
  final int? sourceWidth;
  final int? sourceHeight;
  final String? outputPath;
  final MeiFailure? failure;

  ImageResizeState copyWith({
    ImageToolsStatus? status,
    List<String>? selectedPaths,
    int? targetWidth,
    int? targetHeight,
    bool? lockAspectRatio,
    int? sourceWidth,
    int? sourceHeight,
    String? outputPath,
    MeiFailure? failure,
  }) =>
      ImageResizeState(
        status: status ?? this.status,
        selectedPaths: selectedPaths ?? this.selectedPaths,
        targetWidth: targetWidth ?? this.targetWidth,
        targetHeight: targetHeight ?? this.targetHeight,
        lockAspectRatio: lockAspectRatio ?? this.lockAspectRatio,
        sourceWidth: sourceWidth ?? this.sourceWidth,
        sourceHeight: sourceHeight ?? this.sourceHeight,
        outputPath: outputPath ?? this.outputPath,
        failure: failure ?? this.failure,
      );
}

class ImageToolsState {
  ImageToolsState({
    this.tab = ImageToolsTab.convert,
    ImageConvertState? convertState,
    ImageCompressState? compressState,
    ImageResizeState? resizeState,
    // Backward compatibility:
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
  })  : convertState = convertState ??
            ImageConvertState(
              status: (tab == ImageToolsTab.convert) ? (status ?? ImageToolsStatus.idle) : ImageToolsStatus.idle,
              selectedPaths: (tab == ImageToolsTab.convert) ? (selectedPaths ?? const []) : const [],
              outputFormat: outputFormat ?? 'png',
              outputPath: (tab == ImageToolsTab.convert) ? outputPath : null,
              failure: (tab == ImageToolsTab.convert) ? failure : null,
              progress: progress ?? 0.0,
            ),
        compressState = compressState ??
            ImageCompressState(
              status: (tab == ImageToolsTab.compress) ? (status ?? ImageToolsStatus.idle) : ImageToolsStatus.idle,
              selectedPaths: (tab == ImageToolsTab.compress) ? (selectedPaths ?? const []) : const [],
              quality: quality ?? 80,
              outputPath: (tab == ImageToolsTab.compress) ? outputPath : null,
              failure: (tab == ImageToolsTab.compress) ? failure : null,
            ),
        resizeState = resizeState ??
            ImageResizeState(
              status: (tab == ImageToolsTab.resize) ? (status ?? ImageToolsStatus.idle) : ImageToolsStatus.idle,
              selectedPaths: (tab == ImageToolsTab.resize) ? (selectedPaths ?? const []) : const [],
              targetWidth: targetWidth,
              targetHeight: targetHeight,
              lockAspectRatio: lockAspectRatio ?? true,
              sourceWidth: sourceWidth,
              sourceHeight: sourceHeight,
              outputPath: (tab == ImageToolsTab.resize) ? outputPath : null,
              failure: (tab == ImageToolsTab.resize) ? failure : null,
            );

  final ImageToolsTab tab;
  final ImageConvertState convertState;
  final ImageCompressState compressState;
  final ImageResizeState resizeState;

  // Delegated getters pointing to active tab's sub-state
  ImageToolsStatus get status => switch (tab) {
        ImageToolsTab.convert => convertState.status,
        ImageToolsTab.compress => compressState.status,
        ImageToolsTab.resize => resizeState.status,
      };

  List<String> get selectedPaths => switch (tab) {
        ImageToolsTab.convert => convertState.selectedPaths,
        ImageToolsTab.compress => compressState.selectedPaths,
        ImageToolsTab.resize => resizeState.selectedPaths,
      };

  String? get outputPath => switch (tab) {
        ImageToolsTab.convert => convertState.outputPath,
        ImageToolsTab.compress => compressState.outputPath,
        ImageToolsTab.resize => resizeState.outputPath,
      };

  MeiFailure? get failure => switch (tab) {
        ImageToolsTab.convert => convertState.failure,
        ImageToolsTab.compress => compressState.failure,
        ImageToolsTab.resize => resizeState.failure,
      };

  String get outputFormat => convertState.outputFormat;
  int get quality => compressState.quality;
  int? get targetWidth => resizeState.targetWidth;
  int? get targetHeight => resizeState.targetHeight;
  bool get lockAspectRatio => resizeState.lockAspectRatio;
  int? get sourceWidth => resizeState.sourceWidth;
  int? get sourceHeight => resizeState.sourceHeight;
  double get progress => convertState.progress;

  bool get hasFile => selectedPaths.isNotEmpty;
  bool get isBusy => status == ImageToolsStatus.converting;
  String get primaryPath => selectedPaths.isEmpty ? '' : selectedPaths.first;

  ImageToolsState copyWith({
    ImageToolsTab? tab,
    ImageConvertState? convertState,
    ImageCompressState? compressState,
    ImageResizeState? resizeState,
    // Backward compatibility:
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
  }) {
    final nextTab = tab ?? this.tab;
    return ImageToolsState(
      tab: nextTab,
      convertState: convertState ??
          this.convertState.copyWith(
            status: (nextTab == ImageToolsTab.convert) ? (status ?? this.convertState.status) : this.convertState.status,
            selectedPaths: (nextTab == ImageToolsTab.convert) ? (selectedPaths ?? this.convertState.selectedPaths) : this.convertState.selectedPaths,
            outputFormat: outputFormat ?? this.convertState.outputFormat,
            outputPath: (nextTab == ImageToolsTab.convert) ? (outputPath ?? this.convertState.outputPath) : this.convertState.outputPath,
            failure: (nextTab == ImageToolsTab.convert) ? (failure ?? this.convertState.failure) : this.convertState.failure,
            progress: progress ?? this.convertState.progress,
          ),
      compressState: compressState ??
          this.compressState.copyWith(
            status: (nextTab == ImageToolsTab.compress) ? (status ?? this.compressState.status) : this.compressState.status,
            selectedPaths: (nextTab == ImageToolsTab.compress) ? (selectedPaths ?? this.compressState.selectedPaths) : this.compressState.selectedPaths,
            quality: quality ?? this.compressState.quality,
            outputPath: (nextTab == ImageToolsTab.compress) ? (outputPath ?? this.compressState.outputPath) : this.compressState.outputPath,
            failure: (nextTab == ImageToolsTab.compress) ? (failure ?? this.compressState.failure) : this.compressState.failure,
          ),
      resizeState: resizeState ??
          this.resizeState.copyWith(
            status: (nextTab == ImageToolsTab.resize) ? (status ?? this.resizeState.status) : this.resizeState.status,
            selectedPaths: (nextTab == ImageToolsTab.resize) ? (selectedPaths ?? this.resizeState.selectedPaths) : this.resizeState.selectedPaths,
            targetWidth: targetWidth ?? this.resizeState.targetWidth,
            targetHeight: targetHeight ?? this.resizeState.targetHeight,
            lockAspectRatio: lockAspectRatio ?? this.resizeState.lockAspectRatio,
            sourceWidth: sourceWidth ?? this.resizeState.sourceWidth,
            sourceHeight: sourceHeight ?? this.resizeState.sourceHeight,
            outputPath: (nextTab == ImageToolsTab.resize) ? (outputPath ?? this.resizeState.outputPath) : this.resizeState.outputPath,
            failure: (nextTab == ImageToolsTab.resize) ? (failure ?? this.resizeState.failure) : this.resizeState.failure,
          ),
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ImageToolsNotifier extends Notifier<ImageToolsState> {
  static final _log = MeiLogger.instance;
  static const _uuid = Uuid();

  @override
  ImageToolsState build() => ImageToolsState();

  // Helper updates for sub-states
  void _updateConvert(ImageConvertState Function(ImageConvertState) update) {
    state = state.copyWith(convertState: update(state.convertState));
  }

  void _updateCompress(ImageCompressState Function(ImageCompressState) update) {
    state = state.copyWith(compressState: update(state.compressState));
  }

  void _updateResize(ImageResizeState Function(ImageResizeState) update) {
    state = state.copyWith(resizeState: update(state.resizeState));
  }

  void setTab(ImageToolsTab tab) => state = state.copyWith(tab: tab);

  void setOutputFormat(String fmt) =>
      _updateConvert((s) => s.copyWith(outputFormat: fmt));

  void setQuality(int quality) =>
      _updateCompress((s) => s.copyWith(quality: quality));

  void setTargetWidth(int? w) {
    _updateResize((s) {
      if (s.lockAspectRatio &&
          w != null &&
          s.sourceWidth != null &&
          s.sourceHeight != null) {
        final ratio = s.sourceHeight! / s.sourceWidth!;
        return s.copyWith(targetWidth: w, targetHeight: (w * ratio).round());
      } else {
        return s.copyWith(targetWidth: w);
      }
    });
  }

  void setTargetHeight(int? h) {
    _updateResize((s) {
      if (s.lockAspectRatio &&
          h != null &&
          s.sourceWidth != null &&
          s.sourceHeight != null) {
        final ratio = s.sourceWidth! / s.sourceHeight!;
        return s.copyWith(targetHeight: h, targetWidth: (h * ratio).round());
      } else {
        return s.copyWith(targetHeight: h);
      }
    });
  }

  void toggleAspectLock() {
    _updateResize((s) {
      final nextLock = !s.lockAspectRatio;
      if (nextLock &&
          s.targetWidth != null &&
          s.sourceWidth != null &&
          s.sourceHeight != null) {
        final ratio = s.sourceHeight! / s.sourceWidth!;
        return s.copyWith(
          lockAspectRatio: nextLock,
          targetHeight: (s.targetWidth! * ratio).round(),
        );
      } else {
        return s.copyWith(lockAspectRatio: nextLock);
      }
    });
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

      switch (state.tab) {
        case ImageToolsTab.convert:
          _updateConvert((s) => s.copyWith(
            selectedPaths: paths,
            outputPath: null,
            failure: null,
            status: ImageToolsStatus.idle,
            progress: 0.0,
          ));
        case ImageToolsTab.compress:
          _updateCompress((s) => s.copyWith(
            selectedPaths: paths,
            outputPath: null,
            failure: null,
            status: ImageToolsStatus.idle,
          ));
        case ImageToolsTab.resize:
          _updateResize((s) => s.copyWith(
            selectedPaths: paths,
            outputPath: null,
            failure: null,
            status: ImageToolsStatus.idle,
          ));
          unawaited(_loadDimensions(paths.first));
      }
    } catch (e, st) {
      _log.e('pickFiles failed', e, st);
    }
  }

  Future<void> _loadDimensions(String path) async {
    try {
      final dim = await ImageConverterService.getDimensions(path);
      _updateResize((s) => s.copyWith(
        sourceWidth: dim.width,
        sourceHeight: dim.height,
        targetWidth: dim.width,
        targetHeight: dim.height,
      ));
    } catch (_) {}
  }

  Future<void> convert() async {
    if (!state.hasFile) return;
    _updateConvert((s) => s.copyWith(status: ImageToolsStatus.converting, failure: null));
    try {
      final paths = state.selectedPaths;
      String lastOutput = '';
      for (var i = 0; i < paths.length; i++) {
        _updateConvert((s) => s.copyWith(progress: i / paths.length));
        lastOutput = await ImageConverterService.convert(paths[i], state.outputFormat);
        lastOutput = await FileUtils.moveToPublic(lastOutput);
        await _saveToHistory(
          inputPath: paths[i],
          outputPath: lastOutput,
          inputFormat: _ext(paths[i]),
          outputFormat: state.outputFormat,
          category: 'image',
        );
      }
      _updateConvert((s) => s.copyWith(
        status: ImageToolsStatus.done,
        outputPath: lastOutput,
        progress: 1.0,
      ));
    } catch (e, st) {
      _log.e('convert failed', e, st);
      _updateConvert((s) => s.copyWith(
        status: ImageToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      ));
    }
  }

  Future<void> compress() async {
    if (!state.hasFile) return;
    _updateCompress((s) => s.copyWith(status: ImageToolsStatus.converting, failure: null));
    try {
      var out = await ImageConverterService.compress(state.primaryPath,
          quality: state.quality);
      out = await FileUtils.moveToPublic(out);
      await _saveToHistory(
        inputPath: state.primaryPath,
        outputPath: out,
        inputFormat: _ext(state.primaryPath),
        outputFormat: 'jpg',
        category: 'image',
      );
      _updateCompress((s) => s.copyWith(status: ImageToolsStatus.done, outputPath: out));
    } catch (e, st) {
      _log.e('compress failed', e, st);
      _updateCompress((s) => s.copyWith(
        status: ImageToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      ));
    }
  }

  Future<void> resize() async {
    if (!state.hasFile) return;
    _updateResize((s) => s.copyWith(status: ImageToolsStatus.converting, failure: null));
    try {
      var out = await ImageConverterService.resize(
        state.primaryPath,
        targetWidth: state.targetWidth,
        targetHeight: state.targetHeight,
      );
      out = await FileUtils.moveToPublic(out);
      await _saveToHistory(
        inputPath: state.primaryPath,
        outputPath: out,
        inputFormat: _ext(state.primaryPath),
        outputFormat: _ext(out),
        category: 'image',
      );
      _updateResize((s) => s.copyWith(status: ImageToolsStatus.done, outputPath: out));
    } catch (e, st) {
      _log.e('resize failed', e, st);
      _updateResize((s) => s.copyWith(
        status: ImageToolsStatus.failed,
        failure: ConversionFailure(message: e.toString(), cause: e),
      ));
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
    switch (state.tab) {
      case ImageToolsTab.convert:
        _updateConvert((s) => s.copyWith(status: ImageToolsStatus.idle, outputPath: null, failure: null, progress: 0.0));
      case ImageToolsTab.compress:
        _updateCompress((s) => s.copyWith(status: ImageToolsStatus.idle, outputPath: null, failure: null));
      case ImageToolsTab.resize:
        _updateResize((s) => s.copyWith(status: ImageToolsStatus.idle, outputPath: null, failure: null));
    }
  }

  void reset() {
    switch (state.tab) {
      case ImageToolsTab.convert:
        _updateConvert((s) => const ImageConvertState());
      case ImageToolsTab.compress:
        _updateCompress((s) => const ImageCompressState());
      case ImageToolsTab.resize:
        _updateResize((s) => const ImageResizeState());
    }
  }

  String _ext(String path) => path.split('.').last.toLowerCase();

  void debugUpdateState(ImageToolsState Function(ImageToolsState) update) {
    state = update(state);
  }
}

final imageToolsProvider =
    NotifierProvider<ImageToolsNotifier, ImageToolsState>(
  ImageToolsNotifier.new,
);
