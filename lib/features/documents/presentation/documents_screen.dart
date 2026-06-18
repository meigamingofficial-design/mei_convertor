import 'dart:io';

import 'package:flutter/material.dart';
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
import '../providers/documents_provider.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({
    super.key,
    this.initialTabName,
  });

  final String? initialTabName;

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int _tabIndexFor(String? tabName) {
    if (tabName == null) return 0;
    switch (tabName) {
      case 'toPdf':
      case 'txtToPdf':
        return 0;
      case 'toDocx':
      case 'pdfToDocx':
        return 1;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabIndexFor(widget.initialTabName);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(_onTabChanged);

    if (widget.initialTabName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tab = initialIndex == 0 ? DocumentsTab.toPdf : DocumentsTab.toDocx;
        ref.read(documentsProvider.notifier).setTab(tab);
      });
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final tab = _tabController.index == 0 ? DocumentsTab.toPdf : DocumentsTab.toDocx;
    ref.read(documentsProvider.notifier).setTab(tab);
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
    final state    = ref.watch(documentsProvider);
    final notifier = ref.read(documentsProvider.notifier);

    return Scaffold(
      backgroundColor: MeiColors.offWhite,
      appBar: AppBar(
        title: Text(ref.tr('doc_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (state.hasFile)
            TextButton(
              onPressed: notifier.reset,
              style: TextButton.styleFrom(foregroundColor: MeiColors.error),
              child: Text(ref.tr('doc_label_clear')),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: MeiColors.docGreenDeep,
          unselectedLabelColor: MeiColors.textTertiary,
          indicatorColor: MeiColors.docGreenDeep,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: MeiTextStyles.labelLarge
              .copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: MeiTextStyles.labelLarge,
          tabs: [
            Tab(text: ref.tr('doc_info_to_pdf')),
            Tab(text: ref.tr('doc_info_to_docx')),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: TabBarView(
          controller: _tabController,
          children: const [
            _ConvertTab(targetFormat: DocumentsTab.toPdf),
            _ConvertTab(targetFormat: DocumentsTab.toDocx),
          ],
        ),
      ),
    );
  }
}

// ── Shared conversion tab ─────────────────────────────────────────────────────

class _ConvertTab extends ConsumerWidget {
  const _ConvertTab({required this.targetFormat});
  final DocumentsTab targetFormat;

  bool get _isPdf   => targetFormat == DocumentsTab.toPdf;
  String get _label => _isPdf ? 'PDF' : 'DOCX';
  IconData get _icon =>
      _isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(documentsProvider);
    final notifier = ref.read(documentsProvider.notifier);

    // Only show results/errors that belong to this tab's current state
    final isActive = state.tab == targetFormat;

    return SingleChildScrollView(
      padding: MeiSpacing.pageInsets,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Gap(MeiSpacing.lg),

          if (!state.hasFile)
            MeiEmptyState(
              icon: _icon,
              title: _isPdf
                  ? ref.tr('doc_empty_to_pdf')
                  : ref.tr('doc_empty_to_docx'),
              subtitle: _isPdf
                  ? ref.tr('doc_empty_to_pdf_sub')
                  : ref.tr('doc_empty_to_docx_sub'),
              action: notifier.pickFile,
              actionLabel: ref.tr('doc_btn_select'),
              accentColor: MeiColors.docGreenDeep,
              accentBackground: MeiColors.docGreenLight,
            )
          else ...[
            // Polished Selected File Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MeiSpacing.lg),
              decoration: BoxDecoration(
                color: MeiColors.docGreenLight,
                borderRadius: MeiRadius.xlAll,
                border: Border.all(
                  color: MeiColors.docGreenDeep,
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
                          color: MeiColors.docGreenDeep.withValues(alpha: 0.15),
                          borderRadius: MeiRadius.mdAll,
                        ),
                        child: const Icon(
                          Icons.article_rounded,
                          size: 22,
                          color: MeiColors.docGreenDeep,
                        ),
                      ),
                      const Gap(MeiSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.fileName,
                              style: MeiTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Gap(2),
                            Text(
                              _getFileSize(state.selectedPath!),
                              style: MeiTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(MeiSpacing.md),
                  const Divider(color: MeiColors.docGreen),
                  const Gap(MeiSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: notifier.pickFile,
                        icon: const Icon(Icons.refresh_rounded, size: 16, color: MeiColors.docGreenDeep),
                        label: Text(
                          ref.tr('change_file'),
                          style: MeiTextStyles.labelMedium.copyWith(color: MeiColors.docGreenDeep),
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

            if (state.previewLines.isNotEmpty && state.status != DocumentsStatus.done) ...[
              const Gap(MeiSpacing.xxl),
              Text(ref.tr('preview'), style: MeiTextStyles.headlineSmall),
              const Gap(MeiSpacing.md),
              MeiCard(
                padding: MeiSpacing.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...state.previewLines.take(15).map(
                          (line) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              line.isEmpty ? ' ' : line,
                              style: MeiTextStyles.bodySmall.copyWith(
                                fontFamily: 'monospace',
                                color: MeiColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                    if (state.previewLines.length > 15)
                      Text(
                        ref.tr('doc_preview_more').replaceAll('{count}', '${state.previewLines.length - 15}'),
                        style: MeiTextStyles.labelSmall
                            .copyWith(color: MeiColors.textTertiary),
                      ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms),
            ],

            const Gap(MeiSpacing.xxl),

            // ── Convert button ────────────────────────────────────────────
            if (state.status != DocumentsStatus.done)
              MeiButton(
                label: state.isBusy
                    ? ref.tr('doc_label_converting_to').replaceAll('{format}', _label)
                    : (_isPdf ? ref.tr('doc_btn_convert_pdf') : ref.tr('doc_btn_convert_docx')),
                icon: _icon,
                onPressed: state.isBusy
                    ? null
                    : (_isPdf ? notifier.convertToPdf : notifier.convertToDocx),
                isLoading: state.isBusy,
                width: double.infinity,
                backgroundColor: MeiColors.docGreenDeep,
              ),
          ],

          // ── Progress ────────────────────────────────────────────────────
          if (state.isBusy && isActive)
            const Padding(
              padding: EdgeInsets.only(top: MeiSpacing.lg),
              child: LinearProgressIndicator(),
            ),

          // ── Result ──────────────────────────────────────────────────────
          if (isActive &&
              state.status == DocumentsStatus.done &&
              state.outputPath != null)
            _ResultCard(
              outputPath: state.outputPath!,
              label: _label,
              onReset: notifier.convertAnother,
              inputPath: state.selectedPath!,
            ),

          // ── Error ────────────────────────────────────────────────────────
          if (isActive &&
              state.status == DocumentsStatus.failed &&
              state.failure != null)
            Padding(
              padding: const EdgeInsets.only(top: MeiSpacing.xxl),
              child: MeiCard(
                padding: MeiSpacing.cardPadding,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: MeiColors.error, size: 24),
                    const Gap(MeiSpacing.md),
                    Expanded(
                      child: Text(
                        state.failure!.message,
                        style: MeiTextStyles.bodySmall
                            .copyWith(color: MeiColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const Gap(MeiSpacing.massive),
        ],
      ),
    );
  }
}

// ── Result card ───────────────────────────────────────────────────────────────

class _ResultCard extends ConsumerWidget {
  const _ResultCard({
    required this.outputPath,
    required this.label,
    required this.onReset,
    required this.inputPath,
  });

  final String outputPath;
  final String label;
  final VoidCallback onReset;
  final String inputPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = outputPath.split('/').last;

    int originalSize = 0;
    int convertedSize = 0;
    try {
      convertedSize = File(outputPath).lengthSync();
      originalSize = File(inputPath).lengthSync();
    } catch (_) {}

    final spaceSaved = originalSize > convertedSize ? (((originalSize - convertedSize) / originalSize) * 100).round() : 0;

    final successMsg = label == 'PDF' ? ref.tr('doc_success_pdf') : ref.tr('doc_success_docx');

    return Padding(
      padding: const EdgeInsets.only(top: MeiSpacing.xxl),
      child: MeiCard(
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
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: MeiColors.success,
                    size: 22,
                  ),
                ),
                const Gap(MeiSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        successMsg,
                        style: MeiTextStyles.titleMedium,
                      ),
                      const Gap(2),
                      Text(
                        fileName,
                        style: MeiTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                      foregroundColor: MeiColors.docGreenDeep,
                      side: const BorderSide(color: MeiColors.docGreen),
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
                      backgroundColor: MeiColors.docGreenDeep,
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
                  foregroundColor: MeiColors.docGreenDeep,
                  side: const BorderSide(color: MeiColors.docGreen),
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
                  foregroundColor: MeiColors.docGreenDeep,
                ),
                child: Text(ref.tr('convert_another')),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
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
