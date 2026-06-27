import 'package:flutter_test/flutter_test.dart';
import 'package:mei_convertor/features/pdf_tools/services/pdf_converter_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PDF tools state / notifier unit tests.
//
// We focus on the pure state-management logic: enum transitions, copyWith,
// validation helpers, and list-manipulation methods (reorder, remove) that
// don't require a real filesystem or isolate context.
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── PdfToolsState defaults ────────────────────────────────────────────────

  group('PdfToolsState — defaults', () {
    final state = PdfToolsState();

    test('default tab is imagesToPdf', () {
      expect(state.tab, PdfToolsTab.imagesToPdf);
    });

    test('default status is idle', () {
      expect(state.status, PdfToolsStatus.idle);
    });

    test('sourcePaths starts empty', () {
      expect(state.sourcePaths, isEmpty);
    });

    test('mergePdfPaths starts empty', () {
      expect(state.mergePdfPaths, isEmpty);
    });

    test('splitFromPage defaults to 1', () {
      expect(state.splitFromPage, 1);
    });

    test('splitToPage defaults to 1', () {
      expect(state.splitToPage, 1);
    });



    test('hasFiles is false initially', () {
      expect(state.hasFiles, isFalse);
    });



    test('hasMergePdfs is false initially', () {
      expect(state.hasMergePdfs, isFalse);
    });

    test('hasSplitSource is false initially', () {
      expect(state.hasSplitSource, isFalse);
    });

    test('isBusy is false initially', () {
      expect(state.isBusy, isFalse);
    });
  });

  // ── PdfToolsState.copyWith ────────────────────────────────────────────────

  group('PdfToolsState.copyWith', () {
    final base = PdfToolsState();

    test('copyWith tab', () {
      final s = base.copyWith(tab: PdfToolsTab.mergePdfs);
      expect(s.tab, PdfToolsTab.mergePdfs);
      expect(s.status, PdfToolsStatus.idle); // unchanged
    });

    test('copyWith status', () {
      final s = base.copyWith(status: PdfToolsStatus.converting);
      expect(s.status, PdfToolsStatus.converting);
    });

    test('copyWith sourcePaths', () {
      final s = base.copyWith(sourcePaths: ['/a.jpg', '/b.jpg']);
      expect(s.sourcePaths.length, 2);
      expect(s.sourcePaths.first, '/a.jpg');
    });

    test('copyWith mergePdfPaths', () {
      final s = base.copyWith(mergePdfPaths: ['/x.pdf', '/y.pdf']);
      expect(s.mergePdfPaths.length, 2);
    });

    test('copyWith preserves other fields', () {
      final s = base
          .copyWith(tab: PdfToolsTab.splitPdf)
          .copyWith(splitTotalPages: 10);
      expect(s.tab, PdfToolsTab.splitPdf);
      expect(s.splitTotalPages, 10);
    });



    test('copyWith splitFromPage and splitToPage', () {
      final s =
          base.copyWith(splitFromPage: 3, splitToPage: 7, splitTotalPages: 10);
      expect(s.splitFromPage, 3);
      expect(s.splitToPage, 7);
    });

    test('copyWith outputPath', () {
      final s = base.copyWith(outputPath: '/out/merged.pdf');
      expect(s.outputPath, '/out/merged.pdf');
    });

    test('copyWith splitOutputPaths', () {
      final s = base.copyWith(
          splitOutputPaths: ['/out/part1.pdf', '/out/part2.pdf']);
      expect(s.splitOutputPaths.length, 2);
    });
  });

  // ── PdfToolsState.forTab ──────────────────────────────────────────────────

  group('PdfToolsState.forTab', () {
    test('forTab creates fresh state for the given tab', () {
      final dirty = PdfToolsState(
        tab: PdfToolsTab.imagesToPdf,
        status: PdfToolsStatus.done,
        outputPath: '/some/path.pdf',
      );
      final clean = dirty.forTab(PdfToolsTab.mergePdfs);
      expect(clean.tab, PdfToolsTab.mergePdfs);
      expect(clean.status, PdfToolsStatus.idle);
      expect(clean.outputPath, isNull);
      expect(clean.failure, isNull);
    });
  });

  // ── hasFiles / hasMergePdfs computed helpers ──────────────────────────────

  group('PdfToolsState — computed helpers', () {
    test('hasFiles is true when sourcePaths is non-empty', () {
      final s = PdfToolsState().copyWith(sourcePaths: ['/a.jpg']);
      expect(s.hasFiles, isTrue);
    });

    test('hasMergePdfs is true only when >= 2 paths', () {
      final one = PdfToolsState()
          .copyWith(mergePdfPaths: ['/a.pdf']);
      final two = PdfToolsState()
          .copyWith(mergePdfPaths: ['/a.pdf', '/b.pdf']);
      expect(one.hasMergePdfs, isFalse);
      expect(two.hasMergePdfs, isTrue);
    });

    test('isBusy is true only when status is converting', () {
      final converting =
          PdfToolsState().copyWith(status: PdfToolsStatus.converting);
      final done =
          PdfToolsState().copyWith(status: PdfToolsStatus.done);
      expect(converting.isBusy, isTrue);
      expect(done.isBusy, isFalse);
    });

    test('hasSplitSource is true when splitSourcePath is set', () {
      final s = PdfToolsState().copyWith(splitSourcePath: '/doc.pdf');
      expect(s.hasSplitSource, isTrue);
    });
  });

  // ── splitRangeValid ───────────────────────────────────────────────────────

  group('PdfToolsState.splitRangeValid', () {
    PdfToolsState buildState({
      int? total,
      int from = 1,
      int to = 1,
    }) =>
        PdfToolsState(
          splitTotalPages: total,
          splitFromPage: from,
          splitToPage: to,
        );

    test('invalid when splitTotalPages is null', () {
      expect(buildState().splitRangeValid, isFalse);
    });

    test('valid for single page (1–1) in a 3-page doc', () {
      expect(buildState(total: 3, from: 1, to: 1).splitRangeValid, isTrue);
    });

    test('valid for full range', () {
      expect(buildState(total: 5, from: 1, to: 5).splitRangeValid, isTrue);
    });

    test('valid for mid range', () {
      expect(buildState(total: 10, from: 3, to: 7).splitRangeValid, isTrue);
    });

    test('invalid when from > to', () {
      expect(buildState(total: 5, from: 4, to: 2).splitRangeValid, isFalse);
    });

    test('invalid when from < 1', () {
      expect(buildState(total: 5, from: 0, to: 3).splitRangeValid, isFalse);
    });

    test('invalid when to > total', () {
      expect(buildState(total: 5, from: 1, to: 6).splitRangeValid, isFalse);
    });

    test('invalid when from equals 0 and total is null', () {
      expect(buildState(from: 0, to: 0).splitRangeValid, isFalse);
    });
  });

  // ── List manipulation helpers (mirrors notifier logic) ────────────────────

  group('List reorder/remove helpers', () {
    List<String> reorder(List<String> list, int oldIdx, int newIdx) {
      final updated = List<String>.from(list);
      if (newIdx > oldIdx) newIdx -= 1;
      updated.insert(newIdx, updated.removeAt(oldIdx));
      return updated;
    }

    List<String> remove(List<String> list, int idx) {
      return List<String>.from(list)..removeAt(idx);
    }

    test('reorder moves first item to last', () {
      final result = reorder(['a', 'b', 'c'], 0, 3);
      expect(result, ['b', 'c', 'a']);
    });

    test('reorder moves last item to first', () {
      final result = reorder(['a', 'b', 'c'], 2, 0);
      expect(result, ['c', 'a', 'b']);
    });

    test('reorder maintains length', () {
      final result = reorder(['x', 'y', 'z'], 1, 0);
      expect(result.length, 3);
    });

    test('remove at index 0 leaves tail', () {
      final result = remove(['/a.pdf', '/b.pdf', '/c.pdf'], 0);
      expect(result, ['/b.pdf', '/c.pdf']);
    });

    test('remove at last index leaves head', () {
      final result = remove(['/a.pdf', '/b.pdf', '/c.pdf'], 2);
      expect(result, ['/a.pdf', '/b.pdf']);
    });

    test('remove from single-element list produces empty list', () {
      final result = remove(['/only.pdf'], 0);
      expect(result, isEmpty);
    });
  });

  // ── PdfToolsTab enum ──────────────────────────────────────────────────────

  group('PdfToolsTab enum', () {
    test('contains exactly 3 values', () {
      expect(PdfToolsTab.values.length, 3);
    });

    test('values are imagesToPdf, mergePdfs, splitPdf', () {
      expect(
        PdfToolsTab.values,
        containsAll([
          PdfToolsTab.imagesToPdf,
          PdfToolsTab.mergePdfs,
          PdfToolsTab.splitPdf,
        ]),
      );
    });
  });

  // ── PdfToolsStatus enum ───────────────────────────────────────────────────

  group('PdfToolsStatus enum', () {
    test('contains idle, converting, done, failed', () {
      expect(
        PdfToolsStatus.values,
        containsAll([
          PdfToolsStatus.idle,
          PdfToolsStatus.converting,
          PdfToolsStatus.done,
          PdfToolsStatus.failed,
        ]),
      );
    });
  });
}
