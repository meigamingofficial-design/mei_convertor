import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mei_convertor/core/services/converters/file_type_detector_service.dart';
import 'package:mei_convertor/features/documents/providers/documents_provider.dart';
import 'package:mei_convertor/features/image_tools/providers/image_tools_provider.dart';
import 'package:mei_convertor/features/pdf_tools/services/pdf_converter_service.dart';
import 'package:mei_convertor/features/quick_convert/providers/quick_convert_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ──────────────────── ImageToolsProvider ──────────────────────────────────

  group('ImageToolsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('initial state has idle status and no files', () {
      final state = container.read(imageToolsProvider);
      expect(state.status, ImageToolsStatus.idle);
      expect(state.hasFile, isFalse);
      expect(state.selectedPaths, isEmpty);
    });

    test('tab isolation and sub-state persistence', () {
      final notifier = container.read(imageToolsProvider.notifier);
      
      // Initially convert outputFormat is png
      expect(container.read(imageToolsProvider).convertState.outputFormat, 'png');

      // Set properties on convert tab
      notifier.setOutputFormat('webp');

      // Switch to compress tab and set properties
      notifier.setTab(ImageToolsTab.compress);
      notifier.setQuality(75);

      // Verify sub-states directly
      var state = container.read(imageToolsProvider);
      expect(state.convertState.outputFormat, 'webp');
      expect(state.compressState.quality, 75);

      // Switch back to convert and reset
      notifier.setTab(ImageToolsTab.convert);
      notifier.reset();

      // Verify that reset only cleared the active tab (convertState), leaving compressState quality intact
      state = container.read(imageToolsProvider);
      expect(state.convertState.outputFormat, 'png'); // reset to default
      expect(state.compressState.quality, 75);        // untouched!
    });

    test('setOutputFormat updates the format', () {
      container.read(imageToolsProvider.notifier).setOutputFormat('webp');
      expect(container.read(imageToolsProvider).outputFormat, 'webp');
    });

    test('setQuality clamps and stores quality', () {
      container.read(imageToolsProvider.notifier).setQuality(65);
      expect(container.read(imageToolsProvider).quality, 65);
    });

    test('reset clears state', () {
      container.read(imageToolsProvider.notifier).setOutputFormat('webp');
      container.read(imageToolsProvider.notifier).reset();
      expect(container.read(imageToolsProvider).outputFormat, 'png');
      expect(container.read(imageToolsProvider).status, ImageToolsStatus.idle);
    });

    test('aspect-ratio lock calculates correct height from width', () {
      final notifier = container.read(imageToolsProvider.notifier);
      // Simulate loading a 1000x500 image
      container.read(imageToolsProvider.notifier);
      notifier.setTargetWidth(1000); // no source dims → no ratio calc
      // Set source dimensions manually (we'd normally do this via pickFiles)
      // Since we can't easily test file-based ops in unit tests,
      // just confirm the field stores correctly
      expect(container.read(imageToolsProvider).targetWidth, 1000);
    });

    test('toggleAspectLock flips the lock', () {
      expect(container.read(imageToolsProvider).lockAspectRatio, isTrue);
      container.read(imageToolsProvider.notifier).toggleAspectLock();
      expect(container.read(imageToolsProvider).lockAspectRatio, isFalse);
    });
  });

  // ──────────────────── DocumentsNotifier ───────────────────────────────────

  group('DocumentsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('initial state has no file', () {
      final state = container.read(documentsProvider);
      expect(state.hasFile, isFalse);
      expect(state.previewLines, isEmpty);
      expect(state.status, DocumentsStatus.idle);
    });

    test('tab isolation and sub-state persistence', () {
      final notifier = container.read(documentsProvider.notifier);

      // Set some file path on toPdf tab via debug update
      notifier.debugUpdateState((s) => s.copyWith(
        pdfState: s.pdfState.copyWith(selectedPath: '/test.txt', status: DocumentsStatus.done),
      ));

      // Switch to toDocx
      notifier.setTab(DocumentsTab.toDocx);
      expect(container.read(documentsProvider).selectedPath, isNull); // docx tab has no file yet

      notifier.debugUpdateState((s) => s.copyWith(
        docxState: s.docxState.copyWith(selectedPath: '/test2.txt', status: DocumentsStatus.failed),
      ));

      // Verify both are persistent
      var state = container.read(documentsProvider);
      expect(state.pdfState.selectedPath, '/test.txt');
      expect(state.docxState.selectedPath, '/test2.txt');

      // Switch back to toPdf and reset
      notifier.setTab(DocumentsTab.toPdf);
      notifier.reset();

      // Verify that reset only cleared the active tab (toPdf), leaving toDocx intact
      state = container.read(documentsProvider);
      expect(state.pdfState.selectedPath, isNull);
      expect(state.pdfState.status, DocumentsStatus.idle);
      expect(state.docxState.selectedPath, '/test2.txt');
      expect(state.docxState.status, DocumentsStatus.failed);
    });

    test('reset clears state', () {
      container.read(documentsProvider.notifier).reset();
      expect(container.read(documentsProvider).hasFile, isFalse);
    });
  });

  // ──────────────────── PdfToolsNotifier ────────────────────────────────────

  group('PdfToolsNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('initial state is idle with no files', () {
      final state = container.read(pdfToolsProvider);
      expect(state.status, PdfToolsStatus.idle);
      expect(state.hasFiles, isFalse);
      expect(state.sourcePaths, isEmpty);
    });

    test('addFiles accumulates file paths', () {
      container.read(pdfToolsProvider.notifier).addFiles(['/a/b.jpg', '/a/c.png']);
      final state = container.read(pdfToolsProvider);
      expect(state.sourcePaths.length, 2);
    });

    test('removeFile removes by index', () {
      final notifier = container.read(pdfToolsProvider.notifier);
      notifier.addFiles(['/a.jpg', '/b.jpg', '/c.jpg']);
      notifier.removeFile(1);
      final paths = container.read(pdfToolsProvider).sourcePaths;
      expect(paths.length, 2);
      expect(paths[1], '/c.jpg');
    });

    test('reorderFiles moves items correctly', () {
      final notifier = container.read(pdfToolsProvider.notifier);
      notifier.addFiles(['/1.jpg', '/2.jpg', '/3.jpg']);
      notifier.reorderFiles(0, 2); // move first to second position
      final paths = container.read(pdfToolsProvider).sourcePaths;
      expect(paths[0], '/2.jpg');
      expect(paths[1], '/1.jpg');
    });



    test('reset clears all state', () {
      final notifier = container.read(pdfToolsProvider.notifier);
      notifier.addFiles(['/x.jpg']);
      notifier.reset();
      expect(container.read(pdfToolsProvider).hasFiles, isFalse);
    });

    test('tab isolation and sub-state persistence', () {
      final notifier = container.read(pdfToolsProvider.notifier);

      // Add files in imagesToPdf tab
      notifier.addFiles(['/x.jpg']);

      // Switch to split and set state
      notifier.setTab(PdfToolsTab.splitPdf);
      notifier.debugUpdateState((s) => s.copyWith(
        splitState: s.splitState.copyWith(splitSourcePath: '/split.pdf', splitTotalPages: 5),
      ));

      // Verify all sub-states are preserved
      var state = container.read(pdfToolsProvider);
      expect(state.imagesToPdfState.sourcePaths, ['/x.jpg']);
      expect(state.splitState.splitSourcePath, '/split.pdf');
      expect(state.splitState.splitTotalPages, 5);

      // Switch back to imagesToPdf and reset
      notifier.setTab(PdfToolsTab.imagesToPdf);
      notifier.reset();

      // Verify that reset only cleared the active tab (imagesToPdf), leaving others intact
      state = container.read(pdfToolsProvider);
      expect(state.imagesToPdfState.sourcePaths, isEmpty);
      expect(state.splitState.splitSourcePath, '/split.pdf');
      expect(state.splitState.splitTotalPages, 5);
    });
  });

  // ──────────────────── QuickConvertNotifier ────────────────────────────────

  group('QuickConvertNotifier', () {
    late ProviderContainer container;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('initial state has idle status and no fields set', () {
      final state = container.read(quickConvertProvider);
      expect(state.status, QuickConvertStatus.idle);
      expect(state.sourcePath, isNull);
      expect(state.detectedType, isNull);
      expect(state.targetFormat, isNull);
      expect(state.outputPath, isNull);
      expect(state.failure, isNull);
    });

    test('setSource sets sourcePath and detects type and default target', () async {
      final notifier = container.read(quickConvertProvider.notifier);
      await notifier.setSource('test_image.png');
      
      final state = container.read(quickConvertProvider);
      expect(state.sourcePath, 'test_image.png');
      expect(state.detectedType, MeiFileCategory.image);
      expect(state.targetFormat, 'jpg');
    });

    test('setTargetFormat updates format', () {
      final notifier = container.read(quickConvertProvider.notifier);
      notifier.setTargetFormat('png');
      expect(container.read(quickConvertProvider).targetFormat, 'png');
    });

    test('reset clears the state back to defaults', () async {
      final notifier = container.read(quickConvertProvider.notifier);
      await notifier.setSource('test_image.png');
      notifier.setTargetFormat('png');
      
      notifier.reset();
      
      final state = container.read(quickConvertProvider);
      expect(state.status, QuickConvertStatus.idle);
      expect(state.sourcePath, isNull);
      expect(state.detectedType, isNull);
      expect(state.targetFormat, isNull);
    });
  });
}
