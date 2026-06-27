import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/services/sharing/sharing_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/widgets/mei_button.dart';
import '../../../core/widgets/mei_card.dart';
import '../../../core/widgets/mei_states.dart';
import '../services/pdf_converter_service.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class PdfToolsScreen extends ConsumerStatefulWidget {
  const PdfToolsScreen({
    super.key,
    this.initialTabName,
  });

  final String? initialTabName;

  @override
  ConsumerState<PdfToolsScreen> createState() => _PdfToolsScreenState();
}

class _PdfToolsScreenState extends ConsumerState<PdfToolsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    PdfToolsTab.imagesToPdf,
    PdfToolsTab.mergePdfs,
    PdfToolsTab.splitPdf,
  ];

  int _tabIndexFor(String? tabName) {
    if (tabName == null) return 0;
    switch (tabName) {
      case 'imagesToPdf':
      case 'images_to_pdf':
        return 0;
      case 'mergePdfs':
      case 'merge':
        return 1;
      case 'splitPdf':
      case 'split':
        return 2;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    final providerTab = ref.read(pdfToolsProvider).tab;
    final initialIndex = widget.initialTabName != null
        ? _tabIndexFor(widget.initialTabName)
        : _tabs.indexOf(providerTab);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );
    _tabController.addListener(_onTabChanged);

    if (widget.initialTabName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(pdfToolsProvider.notifier).setTab(_tabs[initialIndex]);
      });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    ref
        .read(pdfToolsProvider.notifier)
        .setTab(_tabs[_tabController.index]);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdfToolsProvider);
    final notifier = ref.read(pdfToolsProvider.notifier);
    final hasFile = switch (state.tab) {
      PdfToolsTab.imagesToPdf => state.imagesToPdfState.sourcePaths.isNotEmpty || state.imagesToPdfState.outputPath != null,
      PdfToolsTab.mergePdfs => state.mergeState.mergePdfPaths.isNotEmpty || state.mergeState.outputPath != null,
      PdfToolsTab.splitPdf => state.splitState.splitSourcePath != null || state.splitState.splitOutputPaths.isNotEmpty || state.splitState.outputPath != null,
    };

    return Scaffold(
      backgroundColor: MeiColors.offWhite,
      appBar: AppBar(
        title: Text(ref.tr('pdf_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (hasFile)
            TextButton(
              onPressed: notifier.reset,
              style: TextButton.styleFrom(foregroundColor: MeiColors.error),
              child: Text(ref.tr('doc_label_clear')),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: MeiColors.pdfRedDeep,
          unselectedLabelColor: MeiColors.textTertiary,
          indicatorColor: MeiColors.pdfRedDeep,
          indicatorSize: TabBarIndicatorSize.label,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle:
              MeiTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: MeiTextStyles.labelLarge,
          tabs: [
            Tab(text: ref.tr('pdf_tab_images_to_pdf')),
            Tab(text: ref.tr('pdf_tab_merge')),
            Tab(text: ref.tr('pdf_tab_split')),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: TabBarView(
          controller: _tabController,
          children: const [
            _ImagesToPdfTab(),
            _MergePdfsTab(),
            _SplitPdfTab(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Red-themed success card that shows Open / Share / action buttons.
class _PdfSuccessCard extends ConsumerWidget {
  const _PdfSuccessCard({
    required this.outputPath,
    required this.title,
    required this.onReset,
    required this.originalPaths,
  });

  final String outputPath;
  final String title;
  final VoidCallback onReset;
  final List<String> originalPaths;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = outputPath.split('/').last;
    final origFmt = originalPaths.isNotEmpty
        ? originalPaths.first.split('.').last.toUpperCase()
        : 'PDF';
    const outFmt = 'PDF';

    int originalSize = 0;
    int convertedSize = 0;
    try {
      convertedSize = File(outputPath).lengthSync();
      for (final p in originalPaths) {
        final f = File(p);
        if (f.existsSync()) {
          originalSize += f.lengthSync();
        }
      }
    } catch (_) {}

    final spaceSaved = originalSize > convertedSize ? (((originalSize - convertedSize) / originalSize) * 100).round() : 0;

    return MeiCard(
      padding: MeiSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: MeiColors.successLight,
                  borderRadius: MeiRadius.mdAll,
                ),
                child: const Icon(Icons.check_circle_rounded,
                      color: MeiColors.success, size: 22),
              ),
              const Gap(MeiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: MeiTextStyles.titleMedium),
                    const Gap(2),
                    Text(fileName,
                        style: MeiTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const Gap(MeiSpacing.lg),
          const Divider(),
          const Gap(MeiSpacing.md),

          // Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(
                label: ref.tr('original_format').replaceAll('{format}', origFmt),
                value: _formatSize(originalSize),
              ),
              _StatItem(
                label: ref.tr('output_format').replaceAll('{format}', outFmt),
                value: _formatSize(convertedSize),
              ),
              if (spaceSaved > 0)
                _StatItem(label: ref.tr('space_saved'), value: '$spaceSaved%'),
            ],
          ),

          const Gap(MeiSpacing.md),
          const Divider(),
          const Gap(MeiSpacing.md),

          // Save location
          Text(
            ref.tr('saved_to'),
            style: MeiTextStyles.labelSmall.copyWith(color: MeiColors.textTertiary),
          ),
          const Gap(4),
          Text(
            ref.tr('output_path_display'),
            style: MeiTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
          ),

          const Gap(MeiSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => SharingService.openFile(outputPath),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MeiColors.pdfRedDeep,
                    side: const BorderSide(color: MeiColors.pdfRed),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(ref.tr('open')),
                ),
              ),
              const Gap(MeiSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => SharingService.shareFile(outputPath),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MeiColors.pdfRedDeep,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(ref.tr('share')),
                ),
              ),
            ],
          ),
          const Gap(MeiSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final dir = await FileUtils.outputDir();
                await SharingService.openFolder(dir.path);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: MeiColors.pdfRedDeep,
                side: const BorderSide(color: MeiColors.pdfRed),
              ),
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: Text(ref.tr('open_folder')),
            ),
          ),
          const Gap(MeiSpacing.sm),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: MeiColors.pdfRedDeep,
                side: const BorderSide(color: MeiColors.pdfRedDeep, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(ref.tr('convert_another')),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0);
  }
}

class _PdfErrorCard extends ConsumerWidget {
  const _PdfErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MeiCard(
      padding: MeiSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: MeiColors.error, size: 22),
              const Gap(MeiSpacing.sm),
              Expanded(
                child: Text(message,
                    style: MeiTextStyles.bodySmall
                        .copyWith(color: MeiColors.error)),
              ),
            ],
          ),
          const Gap(MeiSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: MeiColors.pdfRedDeep,
                side: const BorderSide(color: MeiColors.pdfRed),
              ),
              child: Text(ref.tr('try_again')),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Images → PDF
// ─────────────────────────────────────────────────────────────────────────────

class _ImagesToPdfTab extends ConsumerWidget {
  const _ImagesToPdfTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(pdfToolsProvider);
    final notifier = ref.read(pdfToolsProvider.notifier);
    final sub      = state.imagesToPdfState;
    final done     = sub.status == PdfToolsStatus.done;
    final failed   = sub.status == PdfToolsStatus.failed;
    final isBusy   = sub.status == PdfToolsStatus.converting;

    return SingleChildScrollView(
      padding: MeiSpacing.pageInsets,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(MeiSpacing.lg),

          if (sub.sourcePaths.isEmpty)
            MeiEmptyState(
              icon: Icons.picture_as_pdf_rounded,
              title: ref.tr('pdf_empty_images_to_pdf'),
              subtitle: ref.tr('pdf_empty_images_to_pdf_sub'),
              action: () async {
                final result = await FilePicker.pickFiles(
                  allowMultiple: true,
                  type: FileType.custom,
                  allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
                );
                if (result != null) {
                  notifier.addFiles(
                    result.paths.whereType<String>().toList(),
                  );
                }
              },
              actionLabel: ref.tr('pdf_btn_select_images'),
              accentColor: MeiColors.pdfRedDeep,
              accentBackground: MeiColors.pdfRedLight,
            )
          else ...[
            // Add images button
            MeiButton(
              label: ref.tr('pdf_btn_add_more'),
              icon: Icons.add_photo_alternate_rounded,
              backgroundColor: MeiColors.pdfRedDeep,
              onPressed: () async {
                final result = await FilePicker.pickFiles(
                  allowMultiple: true,
                  type: FileType.custom,
                  allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
                );
                if (result != null) {
                  notifier.addFiles(
                    result.paths.whereType<String>().toList(),
                  );
                }
              },
              width: double.infinity,
            ),
            const Gap(MeiSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ref.tr('pdf_selected_count').replaceAll('{count}', '${sub.sourcePaths.length}'),
                  style: MeiTextStyles.headlineSmall,
                ),
                TextButton.icon(
                  onPressed: notifier.reset,
                  icon: const Icon(Icons.delete_outline_rounded, color: MeiColors.error, size: 16),
                  label: Text(
                    ref.tr('clear_all'),
                    style: MeiTextStyles.labelMedium.copyWith(color: MeiColors.error),
                  ),
                ),
              ],
            ),
            const Gap(MeiSpacing.md),

            // Reorderable file list
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sub.sourcePaths.length,
              onReorderItem: notifier.reorderFilesItem,
              itemBuilder: (context, index) {
                final name = sub.sourcePaths[index].split('/').last;
                final sizeStr = _getFileSize(sub.sourcePaths[index]);
                return _FileListTile(
                  key: ValueKey(sub.sourcePaths[index]),
                  name: name,
                  index: index,
                  icon: Icons.image_rounded,
                  iconColor: MeiColors.pdfRedDeep,
                  iconBgColor: MeiColors.pdfRedLight,
                  onRemove: () => notifier.removeFile(index),
                  sublabel: sizeStr,
                );
              },
            ),

            const Gap(MeiSpacing.xxl),
            if (sub.status != PdfToolsStatus.done)
              MeiButton(
                label: isBusy
                    ? ref.tr('pdf_label_combining').replaceAll('{count}', '${sub.sourcePaths.length}')
                    : ref.tr('pdf_btn_convert'),
                icon: Icons.picture_as_pdf_rounded,
                onPressed: isBusy ? null : notifier.convertToPdf,
                isLoading: isBusy,
                backgroundColor: MeiColors.pdfRedDeep,
                width: double.infinity,
              ),
          ],

          if (isBusy)
            const Padding(
              padding: EdgeInsets.only(top: MeiSpacing.lg),
              child: LinearProgressIndicator(),
            ),

          if (done && sub.outputPath != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfSuccessCard(
                outputPath: sub.outputPath!,
                title: ref.tr('pdf_success_created'),
                onReset: notifier.convertAnother,
                originalPaths: sub.sourcePaths,
              ),
            ),

          if (failed && sub.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfErrorCard(
                message: sub.failure!.message,
                onRetry: notifier.convertToPdf,
              ),
            ),

          const Gap(MeiSpacing.massive),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Merge PDFs
// ─────────────────────────────────────────────────────────────────────────────

class _MergePdfsTab extends ConsumerWidget {
  const _MergePdfsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(pdfToolsProvider);
    final notifier = ref.read(pdfToolsProvider.notifier);
    final sub      = state.mergeState;
    final done     = sub.status == PdfToolsStatus.done;
    final failed   = sub.status == PdfToolsStatus.failed;
    final isBusy   = sub.status == PdfToolsStatus.converting;
    final hasMergePdfs = sub.mergePdfPaths.length >= 2;

    return SingleChildScrollView(
      padding: MeiSpacing.pageInsets,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(MeiSpacing.lg),

          if (sub.mergePdfPaths.isEmpty)
            MeiEmptyState(
              icon: Icons.merge_type_rounded,
              title: ref.tr('pdf_empty_merge'),
              subtitle: ref.tr('pdf_empty_merge_sub'),
              action: () async {
                final result = await FilePicker.pickFiles(
                  allowMultiple: true,
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result != null) {
                  notifier.addMergePdfs(
                    result.paths.whereType<String>().toList(),
                  );
                }
              },
              actionLabel: ref.tr('pdf_btn_select_pdfs'),
              accentColor: MeiColors.pdfRedDeep,
              accentBackground: MeiColors.pdfRedLight,
            )
          else ...[
            // Info card
            MeiCard(
              padding: MeiSpacing.cardPadding,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: MeiColors.pdfRedDeep.withValues(alpha: 0.15),
                      borderRadius: MeiRadius.mdAll,
                    ),
                    child: const Icon(Icons.merge_type_rounded,
                        color: MeiColors.pdfRedDeep, size: 22),
                  ),
                  const Gap(MeiSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ref.tr('pdf_tab_merge'), style: MeiTextStyles.titleMedium),
                        const Gap(2),
                        Text(
                          ref.tr('pdf_info_merge_sub'),
                          style: MeiTextStyles.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
            const Gap(MeiSpacing.xxl),

            // Add PDFs button
            MeiButton(
              label: ref.tr('pdf_btn_add_pdfs'),
              icon: Icons.add_rounded,
              backgroundColor: MeiColors.pdfRedDeep,
              onPressed: () async {
                final result = await FilePicker.pickFiles(
                  allowMultiple: true,
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result != null) {
                  notifier.addMergePdfs(
                    result.paths.whereType<String>().toList(),
                  );
                }
              },
              width: double.infinity,
            ),
            const Gap(MeiSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  ref.tr('pdf_selected_pdfs_count').replaceAll('{count}', '${sub.mergePdfPaths.length}'),
                  style: MeiTextStyles.headlineSmall,
                ),
                TextButton.icon(
                  onPressed: notifier.reset,
                  icon: const Icon(Icons.delete_outline_rounded, color: MeiColors.error, size: 16),
                  label: Text(
                    ref.tr('clear_all'),
                    style: MeiTextStyles.labelMedium.copyWith(color: MeiColors.error),
                  ),
                ),
              ],
            ),
            const Gap(MeiSpacing.md),

            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sub.mergePdfPaths.length,
              onReorderItem: notifier.reorderMergePdfItem,
              itemBuilder: (context, index) {
                final name = sub.mergePdfPaths[index].split('/').last;
                final sizeStr = _getFileSize(sub.mergePdfPaths[index]);
                return _FileListTile(
                  key: ValueKey(sub.mergePdfPaths[index] + index.toString()),
                  name: name,
                  index: index,
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: MeiColors.pdfRedDeep,
                  iconBgColor: MeiColors.pdfRedLight,
                  onRemove: () => notifier.removeMergePdf(index),
                  sublabel: sizeStr,
                );
              },
            ),

            const Gap(MeiSpacing.xxl),
            if (sub.status != PdfToolsStatus.done)
              MeiButton(
                label: isBusy ? ref.tr('pdf_btn_merging') : ref.tr('pdf_btn_merge'),
                icon: Icons.merge_type_rounded,
                onPressed: (hasMergePdfs && !isBusy)
                    ? notifier.mergePdfs
                    : null,
                isLoading: isBusy,
                backgroundColor: MeiColors.pdfRedDeep,
                width: double.infinity,
              ),
          ],

          if (isBusy)
            const Padding(
              padding: EdgeInsets.only(top: MeiSpacing.lg),
              child: LinearProgressIndicator(),
            ),

          if (done && sub.outputPath != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfSuccessCard(
                outputPath: sub.outputPath!,
                title: ref.tr('pdf_success_merged'),
                onReset: notifier.convertAnother,
                originalPaths: sub.mergePdfPaths,
              ),
            ),

          if (failed && sub.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfErrorCard(
                message: sub.failure!.message,
                onRetry: notifier.mergePdfs,
              ),
            ),

          const Gap(MeiSpacing.massive),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4 — Split PDF
// ─────────────────────────────────────────────────────────────────────────────

class _SplitPdfTab extends ConsumerStatefulWidget {
  const _SplitPdfTab();

  @override
  ConsumerState<_SplitPdfTab> createState() => _SplitPdfTabState();
}

class _SplitPdfTabState extends ConsumerState<_SplitPdfTab> {
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  late final FocusNode _fromFocusNode;
  late final FocusNode _toFocusNode;

  @override
  void initState() {
    super.initState();
    final sub = ref.read(pdfToolsProvider).splitState;
    _fromCtrl = TextEditingController(text: sub.splitFromPage.toString());
    _toCtrl   = TextEditingController(text: sub.splitToPage.toString());
    _fromFocusNode = FocusNode();
    _toFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    super.dispose();
  }

  void _syncControllers(PdfSplitState sub) {
    if (!_fromFocusNode.hasFocus) {
      final fromStr = sub.splitFromPage.toString();
      if (_fromCtrl.text != fromStr) {
        _fromCtrl.text = fromStr;
      }
    }
    if (!_toFocusNode.hasFocus) {
      final toStr = sub.splitToPage.toString();
      if (_toCtrl.text != toStr) {
        _toCtrl.text = toStr;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(pdfToolsProvider);
    final notifier = ref.read(pdfToolsProvider.notifier);
    final sub      = state.splitState;

    _syncControllers(sub);

    final done   = sub.status == PdfToolsStatus.done;
    final failed = sub.status == PdfToolsStatus.failed;
    final isActive = state.tab == PdfToolsTab.splitPdf;
    final hasSplitSource = sub.splitSourcePath != null;
    final isBusy = sub.status == PdfToolsStatus.converting;
    final splitRangeValid = sub.splitTotalPages != null &&
        sub.splitFromPage >= 1 &&
        sub.splitToPage >= sub.splitFromPage &&
        sub.splitToPage <= (sub.splitTotalPages ?? 0);

    return SingleChildScrollView(
      padding: MeiSpacing.pageInsets,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(MeiSpacing.lg),

          if (!hasSplitSource)
            MeiEmptyState(
              icon: Icons.call_split_rounded,
              title: ref.tr('pdf_empty_split'),
              subtitle: ref.tr('pdf_empty_split_sub'),
              action: () async {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result?.paths.isNotEmpty == true) {
                  final path = result!.paths.first;
                  if (path != null) {
                    _fromCtrl.text = '1';
                    _toCtrl.text   = '1';
                    await notifier.setSplitSource(path);
                  }
                }
              },
              actionLabel: ref.tr('pdf_btn_select_pdf'),
              accentColor: MeiColors.pdfRedDeep,
              accentBackground: MeiColors.pdfRedLight,
            )
          else ...[
            // Polished Selected File Card (reusing visual system)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MeiSpacing.lg),
              decoration: BoxDecoration(
                color: MeiColors.pdfRedLight,
                borderRadius: MeiRadius.xlAll,
                border: Border.all(
                  color: MeiColors.pdfRedDeep,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: MeiColors.pdfRedDeep.withValues(alpha: 0.15),
                          borderRadius: MeiRadius.mdAll,
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 22,
                          color: MeiColors.pdfRedDeep,
                        ),
                      ),
                      const Gap(MeiSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub.splitSourcePath!.split('/').last,
                              style: MeiTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Gap(2),
                            Text(
                              '${_getFileSize(sub.splitSourcePath!)}${sub.splitTotalPages != null ? ' · ${sub.splitTotalPages} ${ref.tr('pdf_label_pages_suffix')}' : ''}',
                              style: MeiTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(MeiSpacing.md),
                  const Divider(color: MeiColors.pdfRed),
                  const Gap(MeiSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['pdf'],
                          );
                          if (result?.paths.isNotEmpty == true) {
                            final path = result!.paths.first;
                            if (path != null) {
                              _fromCtrl.text = '1';
                              _toCtrl.text   = '1';
                              await notifier.setSplitSource(path);
                            }
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: MeiColors.pdfRedDeep),
                        label: Text(
                          ref.tr('change_file'),
                          style: MeiTextStyles.labelMedium.copyWith(color: MeiColors.pdfRedDeep),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: notifier.reset,
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: MeiColors.error),
                        label: Text(
                          ref.tr('remove_file'),
                          style: MeiTextStyles.labelMedium.copyWith(color: MeiColors.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(MeiSpacing.xxl),

            // Page range inputs
            if (sub.splitTotalPages != null && sub.status != PdfToolsStatus.done) ...[
              Text(ref.tr('pdf_label_range'), style: MeiTextStyles.headlineSmall),
              const Gap(MeiSpacing.sm),
              Text(
                ref.tr('pdf_label_range_sub').replaceAll('{total}', '${sub.splitTotalPages}'),
                style: MeiTextStyles.bodySmall,
              ),
              const Gap(MeiSpacing.lg),

              Row(
                children: [
                  Expanded(
                    child: _PageRangeField(
                      label: ref.tr('pdf_label_from'),
                      controller: _fromCtrl,
                      focusNode: _fromFocusNode,
                      min: 1,
                      max: sub.splitTotalPages ?? 1,
                      onChanged: (v) => notifier.setSplitFromPage(v),
                    ),
                  ),
                  const Gap(MeiSpacing.md),
                  Expanded(
                    child: _PageRangeField(
                      label: ref.tr('pdf_label_to'),
                      controller: _toCtrl,
                      focusNode: _toFocusNode,
                      min: 1,
                      max: sub.splitTotalPages ?? 1,
                      onChanged: (v) => notifier.setSplitToPage(v),
                    ),
                  ),
                ],
              ),

              // Range validation hint
              if (!splitRangeValid && isActive)
                Padding(
                  padding: const EdgeInsets.only(top: MeiSpacing.sm),
                  child: Text(
                    ref.tr('pdf_error_range'),
                    style: MeiTextStyles.labelSmall
                        .copyWith(color: MeiColors.error),
                  ),
                ),

              const Gap(MeiSpacing.xxl),
              MeiButton(
                label: isBusy ? ref.tr('pdf_btn_extracting') : ref.tr('pdf_btn_split'),
                icon: Icons.call_split_rounded,
                onPressed:
                    (splitRangeValid && !isBusy)
                        ? notifier.splitPdf
                        : null,
                isLoading: isBusy,
                backgroundColor: MeiColors.pdfRedDeep,
                width: double.infinity,
              ),
            ],
          ],

          if (isBusy && isActive)
            const Padding(
              padding: EdgeInsets.only(top: MeiSpacing.lg),
              child: LinearProgressIndicator(),
            ),

          // Split success — show both output files
          if (done && sub.splitOutputPaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.tr('pdf_success_split'),
                      style: MeiTextStyles.headlineSmall),
                  const Gap(MeiSpacing.md),
                  ...sub.splitOutputPaths.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: MeiSpacing.md),
                          child: _PdfSuccessCard(
                            outputPath: e.value,
                            title: e.key == 0
                                ? ref.tr('pdf_success_split_extracted')
                                    .replaceAll('{from}', '${sub.splitFromPage}')
                                    .replaceAll('{to}', '${sub.splitToPage}')
                                : ref.tr('pdf_success_split_remainder'),
                            onReset: notifier.convertAnother,
                            originalPaths: [sub.splitSourcePath!],
                          ),
                        ),
                      ),
                ],
              ),
            ),

          if (failed && sub.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfErrorCard(
                message: sub.failure!.message,
                onRetry: notifier.splitPdf,
              ),
            ),

          const Gap(MeiSpacing.massive),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

/// A reorderable list tile for a file entry.
class _FileListTile extends StatelessWidget {
  const _FileListTile({
    required super.key,
    required this.name,
    required this.index,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.onRemove,
    this.sublabel,
  });

  final String name;
  final int index;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final VoidCallback onRemove;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    return MeiCard(
      padding: const EdgeInsets.symmetric(
          horizontal: MeiSpacing.md, vertical: MeiSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: MeiRadius.smAll,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const Gap(MeiSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: MeiTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sublabel != null) ...[
                  const Gap(2),
                  Text(
                    sublabel!,
                    style: MeiTextStyles.labelSmall.copyWith(color: MeiColors.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18,
                color: MeiColors.error), // Use red for deletion/remove!
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const Icon(Icons.drag_handle_rounded,
              size: 18, color: MeiColors.textTertiary),
        ],
      ),
    );
  }
}

/// Validated text field for entering a page number.
class _PageRangeField extends StatelessWidget {
  const _PageRangeField({
    required this.label,
    required this.controller,
    required this.min,
    required this.max,
    required this.onChanged,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final int min;
  final int max;
  final void Function(int) onChanged;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MeiTextStyles.labelLarge),
        const Gap(MeiSpacing.xs),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: MeiTextStyles.titleMedium,
          decoration: InputDecoration(
            filled: true,
            fillColor: MeiColors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 14),
            border: const OutlineInputBorder(
              borderRadius: MeiRadius.mdAll,
              borderSide: BorderSide(color: MeiColors.border),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: MeiRadius.mdAll,
              borderSide: BorderSide(color: MeiColors.border),
            ),
            hintText: '$min–$max',
            hintStyle: MeiTextStyles.bodySmall,
          ),
          onChanged: (value) {
            final v = int.tryParse(value);
            if (v != null && v >= min && v <= max) {
              onChanged(v);
            }
          },
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MeiTextStyles.labelSmall.copyWith(color: MeiColors.textTertiary)),
        const Gap(4),
        Text(value, style: MeiTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

String _getFileSize(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return '';
    final bytes = file.lengthSync();
    return _formatSize(bytes);
  } catch (_) {
    return '';
  }
}

String _formatSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}
