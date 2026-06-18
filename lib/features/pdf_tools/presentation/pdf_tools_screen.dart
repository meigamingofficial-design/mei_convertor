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
    PdfToolsTab.compress,
    PdfToolsTab.mergePdfs,
    PdfToolsTab.splitPdf,
  ];

  int _tabIndexFor(String? tabName) {
    if (tabName == null) return 0;
    switch (tabName) {
      case 'imagesToPdf':
      case 'images_to_pdf':
        return 0;
      case 'compress':
        return 1;
      case 'mergePdfs':
      case 'merge':
        return 2;
      case 'splitPdf':
      case 'split':
        return 3;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabIndexFor(widget.initialTabName);
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: initialIndex,
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
    return Scaffold(
      backgroundColor: MeiColors.offWhite,
      appBar: AppBar(
        title: Text(ref.tr('pdf_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
            Tab(text: ref.tr('pdf_tab_compress')),
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
            _CompressTab(),
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
              _StatItem(label: ref.tr('original_size'), value: _formatSize(originalSize)),
              _StatItem(label: ref.tr('new_size'), value: _formatSize(convertedSize)),
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
                await SharingService.openFile(dir.path);
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
            child: TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                foregroundColor: MeiColors.pdfRedDeep,
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
    final done     = state.status == PdfToolsStatus.done && state.tab == PdfToolsTab.imagesToPdf;
    final failed   = state.status == PdfToolsStatus.failed && state.tab == PdfToolsTab.imagesToPdf;

    return SingleChildScrollView(
      padding: MeiSpacing.pageInsets,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(MeiSpacing.lg),

          if (state.sourcePaths.isEmpty)
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
                  ref.tr('pdf_selected_count').replaceAll('{count}', '${state.sourcePaths.length}'),
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
              itemCount: state.sourcePaths.length,
              onReorderItem: notifier.reorderFilesItem,
              itemBuilder: (context, index) {
                final name = state.sourcePaths[index].split('/').last;
                final sizeStr = _getFileSize(state.sourcePaths[index]);
                return _FileListTile(
                  key: ValueKey(state.sourcePaths[index]),
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
            if (state.status != PdfToolsStatus.done)
              MeiButton(
                label: state.isBusy
                    ? ref.tr('pdf_label_combining').replaceAll('{count}', '${state.sourcePaths.length}')
                    : ref.tr('pdf_btn_convert'),
                icon: Icons.picture_as_pdf_rounded,
                onPressed: state.isBusy ? null : notifier.convertToPdf,
                isLoading: state.isBusy,
                backgroundColor: MeiColors.pdfRedDeep,
                width: double.infinity,
              ),
          ],

          if (state.isBusy)
            const Padding(
              padding: EdgeInsets.only(top: MeiSpacing.lg),
              child: LinearProgressIndicator(),
            ),

          if (done && state.outputPath != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfSuccessCard(
                outputPath: state.outputPath!,
                title: ref.tr('pdf_success_created'),
                onReset: notifier.convertAnother,
                originalPaths: state.sourcePaths,
              ),
            ),

          if (failed && state.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfErrorCard(
                message: state.failure!.message,
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
// Tab 2 — Compress
// ─────────────────────────────────────────────────────────────────────────────

class _CompressTab extends ConsumerWidget {
  const _CompressTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(pdfToolsProvider);
    final notifier = ref.read(pdfToolsProvider.notifier);
    final done     = state.status == PdfToolsStatus.done && state.tab == PdfToolsTab.compress;
    final failed   = state.status == PdfToolsStatus.failed && state.tab == PdfToolsTab.compress;

    return SingleChildScrollView(
      padding: MeiSpacing.pageInsets,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(MeiSpacing.lg),

          if (!state.hasPdf)
            MeiEmptyState(
              icon: Icons.compress_rounded,
              title: ref.tr('pdf_empty_compress'),
              subtitle: ref.tr('pdf_empty_compress_sub'),
              action: () async {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result?.paths.isNotEmpty == true) {
                  final path = result!.paths.first;
                  if (path != null) notifier.setPdfSource(path);
                }
              },
              actionLabel: ref.tr('pdf_btn_select_pdf'),
              accentColor: MeiColors.pdfRedDeep,
              accentBackground: MeiColors.pdfRedLight,
            )
          else ...[
            // Polished Selected File Card (reusing visual system from image tools)
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
                              state.pdfSourcePath!.split('/').last,
                              style: MeiTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Gap(2),
                            Text(
                              _getFileSize(state.pdfSourcePath!),
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
                            if (path != null) notifier.setPdfSource(path);
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

            if (state.status != PdfToolsStatus.done)
              MeiButton(
                label: state.isBusy ? ref.tr('pdf_btn_compressing') : ref.tr('pdf_btn_compress'),
                icon: Icons.compress_rounded,
                onPressed: state.isBusy ? null : notifier.compressPdf,
                isLoading: state.isBusy,
                backgroundColor: MeiColors.pdfRedDeep,
                width: double.infinity,
              ),
          ],

          if (state.isBusy)
            const Padding(
              padding: EdgeInsets.only(top: MeiSpacing.lg),
              child: LinearProgressIndicator(),
            ),

          if (done && state.outputPath != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfSuccessCard(
                outputPath: state.outputPath!,
                title: ref.tr('pdf_success_compressed'),
                onReset: notifier.convertAnother,
                originalPaths: [state.pdfSourcePath!],
              ),
            ),

          if (failed && state.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfErrorCard(
                message: state.failure!.message,
                onRetry: notifier.compressPdf,
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
    final done     = state.status == PdfToolsStatus.done && state.tab == PdfToolsTab.mergePdfs;
    final failed   = state.status == PdfToolsStatus.failed && state.tab == PdfToolsTab.mergePdfs;

    return SingleChildScrollView(
      padding: MeiSpacing.pageInsets,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(MeiSpacing.lg),

          if (state.mergePdfPaths.isEmpty)
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
                  ref.tr('pdf_selected_pdfs_count').replaceAll('{count}', '${state.mergePdfPaths.length}'),
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
              itemCount: state.mergePdfPaths.length,
              onReorderItem: notifier.reorderMergePdfItem,
              itemBuilder: (context, index) {
                final name = state.mergePdfPaths[index].split('/').last;
                final sizeStr = _getFileSize(state.mergePdfPaths[index]);
                return _FileListTile(
                  key: ValueKey(state.mergePdfPaths[index] + index.toString()),
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
            if (state.status != PdfToolsStatus.done)
              MeiButton(
                label: state.isBusy ? ref.tr('pdf_btn_merging') : ref.tr('pdf_btn_merge'),
                icon: Icons.merge_type_rounded,
                onPressed: (state.hasMergePdfs && !state.isBusy)
                    ? notifier.mergePdfs
                    : null,
                isLoading: state.isBusy,
                backgroundColor: MeiColors.pdfRedDeep,
                width: double.infinity,
              ),
          ],

          if (state.isBusy)
            const Padding(
              padding: EdgeInsets.only(top: MeiSpacing.lg),
              child: LinearProgressIndicator(),
            ),

          if (done && state.outputPath != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfSuccessCard(
                outputPath: state.outputPath!,
                title: ref.tr('pdf_success_merged'),
                onReset: notifier.convertAnother,
                originalPaths: state.mergePdfPaths,
              ),
            ),

          if (failed && state.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfErrorCard(
                message: state.failure!.message,
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

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: '1');
    _toCtrl   = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(PdfToolsState state) {
    // Keep text fields in sync when splitTotalPages changes
    if (state.splitTotalPages != null) {
      if (_toCtrl.text != state.splitTotalPages.toString() &&
          state.splitToPage == state.splitTotalPages) {
        _toCtrl.text = state.splitTotalPages.toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(pdfToolsProvider);
    final notifier = ref.read(pdfToolsProvider.notifier);

    _syncControllers(state);

    final done   = state.status == PdfToolsStatus.done && state.tab == PdfToolsTab.splitPdf;
    final failed = state.status == PdfToolsStatus.failed && state.tab == PdfToolsTab.splitPdf;
    final isActive = state.tab == PdfToolsTab.splitPdf;

    return SingleChildScrollView(
      padding: MeiSpacing.pageInsets,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(MeiSpacing.lg),

          if (!state.hasSplitSource)
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
                              state.splitSourcePath!.split('/').last,
                              style: MeiTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Gap(2),
                            Text(
                              '${_getFileSize(state.splitSourcePath!)}${state.splitTotalPages != null ? ' · ${state.splitTotalPages} ${ref.tr('pdf_label_pages_suffix')}' : ''}',
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
            if (state.splitTotalPages != null && state.status != PdfToolsStatus.done) ...[
              Text(ref.tr('pdf_label_range'), style: MeiTextStyles.headlineSmall),
              const Gap(MeiSpacing.sm),
              Text(
                ref.tr('pdf_label_range_sub').replaceAll('{total}', '${state.splitTotalPages}'),
                style: MeiTextStyles.bodySmall,
              ),
              const Gap(MeiSpacing.lg),

              Row(
                children: [
                  Expanded(
                    child: _PageRangeField(
                      label: ref.tr('pdf_label_from'),
                      controller: _fromCtrl,
                      min: 1,
                      max: state.splitTotalPages ?? 1,
                      onChanged: (v) => notifier.setSplitFromPage(v),
                    ),
                  ),
                  const Gap(MeiSpacing.md),
                  Expanded(
                    child: _PageRangeField(
                      label: ref.tr('pdf_label_to'),
                      controller: _toCtrl,
                      min: 1,
                      max: state.splitTotalPages ?? 1,
                      onChanged: (v) => notifier.setSplitToPage(v),
                    ),
                  ),
                ],
              ),

              // Range validation hint
              if (!state.splitRangeValid && isActive)
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
                label: state.isBusy ? ref.tr('pdf_btn_extracting') : ref.tr('pdf_btn_split'),
                icon: Icons.call_split_rounded,
                onPressed:
                    (state.splitRangeValid && !state.isBusy)
                        ? notifier.splitPdf
                        : null,
                isLoading: state.isBusy,
                backgroundColor: MeiColors.pdfRedDeep,
                width: double.infinity,
              ),
            ],
          ],

          if (state.isBusy && isActive)
            const Padding(
              padding: EdgeInsets.only(top: MeiSpacing.lg),
              child: LinearProgressIndicator(),
            ),

          // Split success — show both output files
          if (done && state.splitOutputPaths.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.tr('pdf_success_split'),
                      style: MeiTextStyles.headlineSmall),
                  const Gap(MeiSpacing.md),
                  ...state.splitOutputPaths.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: MeiSpacing.md),
                          child: _PdfSuccessCard(
                            outputPath: e.value,
                            title: e.key == 0
                                ? ref.tr('pdf_success_split_extracted')
                                    .replaceAll('{from}', '${state.splitFromPage}')
                                    .replaceAll('{to}', '${state.splitToPage}')
                                : ref.tr('pdf_success_split_remainder'),
                            onReset: notifier.convertAnother,
                            originalPaths: [state.splitSourcePath!],
                          ),
                        ),
                      ),
                ],
              ),
            ),

          if (failed && state.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: _PdfErrorCard(
                message: state.failure!.message,
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
  });

  final String label;
  final TextEditingController controller;
  final int min;
  final int max;
  final void Function(int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MeiTextStyles.labelLarge),
        const Gap(MeiSpacing.xs),
        TextField(
          controller: controller,
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
