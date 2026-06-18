import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/services/converters/file_type_detector_service.dart';
import '../../../core/services/sharing/sharing_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/widgets/mei_button.dart';
import '../../../core/widgets/mei_card.dart';
import '../../../core/widgets/mei_states.dart';
import '../../../routing/app_router.dart';
import '../../image_tools/services/image_converter_service.dart';
import '../providers/quick_convert_provider.dart';

// ── Quick Convert screen ───────────────────────────────────────────────────────

class QuickConvertScreen extends ConsumerStatefulWidget {
  const QuickConvertScreen({super.key});

  @override
  ConsumerState<QuickConvertScreen> createState() => _QuickConvertScreenState();
}

class _QuickConvertScreenState extends ConsumerState<QuickConvertScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(quickConvertProvider);
    final notifier = ref.read(quickConvertProvider.notifier);

    final detectedType = state.sourcePath != null
        ? FileTypeDetectorService.detectFromPath(state.sourcePath!)
        : null;

    final selectedConversion = state.targetFormat;
    final converting = state.status == QuickConvertStatus.converting;
    final done = state.status == QuickConvertStatus.done;
    final failed = state.status == QuickConvertStatus.failed;
    final outputPath = state.outputPath;
    final errorMessage = state.failure?.message;

    // Resize is a special case: needs Image Tools
    final isResizeSelected = selectedConversion == 'resize';

    return Scaffold(
      backgroundColor: MeiColors.offWhite,
      appBar: AppBar(
        title: Text(ref.tr('quick_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: MeiSpacing.pageInsets,
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(MeiSpacing.lg),

                if (!state.hasSource)
                  MeiEmptyState(
                    icon: Icons.upload_file_rounded,
                    title: ref.tr('quick_empty'),
                    subtitle: ref.tr('quick_empty_sub'),
                    action: () async {
                      final result = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: const [
                          'jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic',
                          'pdf', 'txt', 'docx', 'doc',
                        ],
                      );
                      if (result?.paths.isNotEmpty == true) {
                        final path = result!.paths.first;
                        if (path != null) _onFilePicked(path);
                      }
                    },
                    actionLabel: ref.tr('doc_btn_select'),
                  )
                else ...[
                  _SelectedFileCard(
                    path: state.sourcePath!,
                    category: state.detectedType ?? MeiFileCategory.unknown,
                    onReset: _reset,
                    onChange: () async {
                      final result = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: const [
                          'jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic',
                          'pdf', 'txt', 'docx', 'doc',
                        ],
                      );
                      if (result?.paths.isNotEmpty == true) {
                        final path = result!.paths.first;
                        if (path != null) _onFilePicked(path);
                      }
                    },
                  ),

                  if (detectedType != null && detectedType.isSupported) ...[
                    const Gap(MeiSpacing.xl),
                    _FileInfoCard(
                        fileType: detectedType, filePath: state.sourcePath!),
                    const Gap(MeiSpacing.xl),
                    _ConversionSelector(
                      fileType: detectedType,
                      selected: selectedConversion,
                      onSelected: (conversion) {
                        notifier.setTargetFormat(conversion);
                      },
                    ),
                  ],
                ],

                // Resize redirect card
                if (isResizeSelected) ...[
                  const Gap(MeiSpacing.xl),
                  _ResizeRedirectCard(
                    onGoToImageTools: () => context.push(MeiRoutes.imageTools),
                  ),
                ],

                // Convert button (only shown when NOT resize and not done)
                if (selectedConversion != null && !isResizeSelected && !done) ...[
                  const Gap(MeiSpacing.xl),
                  MeiButton(
                    label: converting
                        ? ref.tr('quick_btn_converting')
                        : ref.tr('quick_btn_convert').replaceAll('{format}', _formatLabel(selectedConversion, ref)),
                    icon: Icons.transform_rounded,
                    onPressed: converting ? null : _convert,
                    isLoading: converting,
                    width: double.infinity,
                  ),
                ],

                if (converting)
                  const Padding(
                    padding: EdgeInsets.only(top: MeiSpacing.lg),
                    child: _AnimatedProgress(),
                  ),

                // Success result
                if (done && outputPath != null)
                  Padding(
                    padding: const EdgeInsets.only(top: MeiSpacing.xl),
                    child: _SuccessCard(
                      outputPath: outputPath,
                      sourcePath: state.sourcePath!,
                      onReset: notifier.convertAnother,
                    ),
                  ),

                // Error
                if (failed && errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: MeiSpacing.xl),
                    child: _ErrorCard(
                      message: errorMessage,
                      onRetry: _convert,
                    ),
                  ),

                const Gap(MeiSpacing.massive),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onFilePicked(String path) {
    ref.read(quickConvertProvider.notifier).setSource(path);
  }

  void _reset() {
    ref.read(quickConvertProvider.notifier).reset();
  }

  Future<void> _convert() async {
    await ref.read(quickConvertProvider.notifier).convert();
  }

  String _formatLabel(String fmt, WidgetRef ref) {
    switch (fmt) {
      case 'compress':
        return ref.tr('image_tab_compress');
      case 'resize':
        return ref.tr('image_tab_resize');
      default:
        return fmt.toUpperCase();
    }
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _SelectedFileCard extends ConsumerStatefulWidget {
  const _SelectedFileCard({
    required this.path,
    required this.category,
    required this.onReset,
    required this.onChange,
  });

  final String path;
  final MeiFileCategory category;
  final VoidCallback onReset;
  final VoidCallback onChange;

  @override
  ConsumerState<_SelectedFileCard> createState() => _SelectedFileCardState();
}

class _SelectedFileCardState extends ConsumerState<_SelectedFileCard> {
  String? _dimensions;

  @override
  void initState() {
    super.initState();
    _loadDimensions();
  }

  @override
  void didUpdateWidget(_SelectedFileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _loadDimensions();
    }
  }

  Future<void> _loadDimensions() async {
    if (widget.category != MeiFileCategory.image) {
      setState(() => _dimensions = null);
      return;
    }
    try {
      final dims = await ImageConverterService.getDimensions(widget.path);
      if (mounted) {
        setState(() => _dimensions = '${dims.width} × ${dims.height}');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _dimensions = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.path.split('/').last;
    final ext = widget.path.split('.').last.toUpperCase();
    int? sizeBytes;
    try {
      sizeBytes = File(widget.path).lengthSync();
    } catch (_) {}

    final sizeStr = sizeBytes != null ? _formatSize(sizeBytes) : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MeiSpacing.lg),
      decoration: BoxDecoration(
        color: MeiColors.sakuraLighter,
        borderRadius: MeiRadius.xlAll,
        border: Border.all(
          color: MeiColors.sakuraDeep,
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
                  color: MeiColors.sakuraDeep.withValues(alpha: 0.15),
                  borderRadius: MeiRadius.mdAll,
                ),
                child: Center(
                  child: Text(
                    ext,
                    style: MeiTextStyles.labelMedium.copyWith(
                      color: MeiColors.sakuraDeep,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const Gap(MeiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: MeiTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      '$sizeStr${_dimensions != null ? ' · $_dimensions' : ''}',
                      style: MeiTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(MeiSpacing.md),
          const Divider(color: MeiColors.sakuraLight),
          const Gap(MeiSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: widget.onChange,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: MeiColors.sakuraDeep),
                label: Text(
                  ref.tr('change_file'),
                  style: MeiTextStyles.labelMedium.copyWith(color: MeiColors.sakuraDeep),
                ),
              ),
              TextButton.icon(
                onPressed: widget.onReset,
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
    );
  }
}

class _FileInfoCard extends ConsumerWidget {
  const _FileInfoCard({required this.fileType, required this.filePath});
  final MeiFileType fileType;
  final String filePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider);
    return MeiCard(
      padding: MeiSpacing.cardPadding,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: MeiColors.sakuraDeep.withValues(alpha: 0.15),
              borderRadius: MeiRadius.mdAll,
            ),
            child: Icon(
              switch (fileType.category) {
                MeiFileCategory.image => Icons.image_rounded,
                MeiFileCategory.pdf => Icons.picture_as_pdf_rounded,
                MeiFileCategory.text => Icons.article_rounded,
                MeiFileCategory.document => Icons.description_rounded,
                _ => Icons.insert_drive_file_rounded,
              },
              color: MeiColors.sakuraDeep,
              size: 22,
            ),
          ),
          const Gap(MeiSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileType.displayName,
                    style: MeiTextStyles.titleMedium),
                const Gap(MeiSpacing.xxs),
                Text(
                  lang == AppLanguage.ja
                      ? '.${fileType.extension.toUpperCase()} ファイル'
                      : '.${fileType.extension.toUpperCase()} file',
                  style: MeiTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: MeiColors.sakuraDeep.withValues(alpha: 0.15),
              borderRadius: MeiRadius.fullAll,
            ),
            child: Text(
              fileType.extension.toUpperCase(),
              style: MeiTextStyles.labelSmall.copyWith(
                color: MeiColors.sakuraDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06, end: 0, duration: 300.ms);
  }
}

// Icon mapping for conversion chips
IconData _iconForConversion(String conversion) => switch (conversion) {
      'jpg' || 'jpeg' => Icons.image_rounded,
      'png' => Icons.image_outlined,
      'webp' => Icons.web_rounded,
      'bmp' => Icons.photo_library_rounded,
      'pdf' => Icons.picture_as_pdf_rounded,
      'compress' => Icons.compress_rounded,
      'resize' => Icons.aspect_ratio_rounded,
      'docx' => Icons.description_rounded,
      'txt' => Icons.article_rounded,
      _ => Icons.transform_rounded,
    };

String _labelForConversion(String conversion, WidgetRef ref) => switch (conversion) {
      'compress' => ref.tr('image_tab_compress'),
      'resize' => ref.tr('image_tab_resize'),
      'jpg' || 'jpeg' => 'JPG',
      'png' => 'PNG',
      'webp' => 'WEBP',
      'bmp' => 'BMP',
      'pdf' => 'PDF',
      'docx' => 'DOCX',
      'txt' => 'TXT',
      _ => conversion.toUpperCase(),
    };

class _ConversionSelector extends ConsumerWidget {
  const _ConversionSelector({
    required this.fileType,
    required this.selected,
    required this.onSelected,
  });

  final MeiFileType fileType;
  final String? selected;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ref.tr('quick_label_convert_to'), style: MeiTextStyles.headlineSmall),
        const Gap(MeiSpacing.md),
        Wrap(
          spacing: MeiSpacing.sm,
          runSpacing: MeiSpacing.sm,
          children: fileType.availableConversions
              .map(
                (conversion) => _ConversionChip(
                  label: _labelForConversion(conversion, ref),
                  icon: _iconForConversion(conversion),
                  isSelected: selected == conversion,
                  isSpecial: conversion == 'resize' || conversion == 'compress',
                  onTap: () => onSelected(conversion),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ConversionChip extends StatefulWidget {
  const _ConversionChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.isSpecial = false,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isSpecial;
  final VoidCallback onTap;

  @override
  State<_ConversionChip> createState() => _ConversionChipState();
}

class _ConversionChipState extends State<_ConversionChip> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected ? MeiColors.sakuraDeep : MeiColors.white,
            borderRadius: MeiRadius.fullAll,
            border: Border.all(
              color: widget.isSelected ? MeiColors.sakuraDeep : MeiColors.border,
              width: 1.5,
            ),
            boxShadow: widget.isSelected ? MeiShadows.soft : MeiShadows.none,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isSelected
                    ? MeiColors.white
                    : (widget.isSpecial
                        ? MeiColors.sakuraDeep
                        : MeiColors.textSecondary),
              ),
              const Gap(6),
              Text(
                widget.label,
                style: MeiTextStyles.labelLarge.copyWith(
                  color: widget.isSelected
                      ? MeiColors.white
                      : (widget.isSpecial
                          ? MeiColors.sakuraDeep
                          : MeiColors.textSecondary),
                  fontWeight: widget.isSelected || widget.isSpecial
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Resize redirect card — instead of a broken convert, guide user to Image Tools
class _ResizeRedirectCard extends ConsumerWidget {
  const _ResizeRedirectCard({required this.onGoToImageTools});
  final VoidCallback onGoToImageTools;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                decoration: BoxDecoration(
                  color: MeiColors.sakuraDeep.withValues(alpha: 0.15),
                  borderRadius: MeiRadius.mdAll,
                ),
                child: const Icon(
                  Icons.aspect_ratio_rounded,
                  color: MeiColors.sakuraDeep,
                  size: 22,
                ),
              ),
              const Gap(MeiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ref.tr('quick_resize_warning'),
                        style: MeiTextStyles.titleMedium),
                    const Gap(2),
                    Text(
                      ref.tr('quick_resize_warning_sub'),
                      style: MeiTextStyles.bodySmall,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(MeiSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onGoToImageTools,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(ref.tr('quick_resize_btn')),
              style: ElevatedButton.styleFrom(
                backgroundColor: MeiColors.sakuraDeep,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0);
  }
}

class _AnimatedProgress extends ConsumerWidget {
  const _AnimatedProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        const ClipRRect(
          borderRadius: MeiRadius.smAll,
          child: LinearProgressIndicator(minHeight: 3),
        ),
        const Gap(MeiSpacing.sm),
        Text(ref.tr('quick_btn_converting'), style: MeiTextStyles.bodySmall),
      ],
    );
  }
}

class _SuccessCard extends ConsumerWidget {
  const _SuccessCard({
    required this.outputPath,
    required this.sourcePath,
    required this.onReset,
  });

  final String outputPath;
  final String sourcePath;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = outputPath.split('/').last;

    int originalSize = 0;
    int convertedSize = 0;
    try {
      convertedSize = File(outputPath).lengthSync();
      originalSize = File(sourcePath).lengthSync();
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
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: MeiColors.successLight,
                  borderRadius: MeiRadius.mdAll,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: MeiColors.success, size: 24),
              ),
              const Gap(MeiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ref.tr('quick_success'),
                        style: MeiTextStyles.titleMedium),
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
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(ref.tr('open')),
                ),
              ),
              const Gap(MeiSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => SharingService.shareFile(outputPath),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: Text(ref.tr('share')),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: MeiColors.sakuraDeep),
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
              icon: const Icon(Icons.folder_open_rounded, size: 16),
              label: Text(ref.tr('open_folder')),
            ),
          ),
          const Gap(MeiSpacing.sm),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: onReset,
              child: Text(ref.tr('convert_another_file')),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

class _ErrorCard extends ConsumerWidget {
  const _ErrorCard({required this.message, required this.onRetry});
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
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: MeiColors.errorLight,
                  borderRadius: MeiRadius.mdAll,
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: MeiColors.error, size: 20),
              ),
              const Gap(MeiSpacing.md),
              Expanded(
                child: Text(
                  message,
                  style: MeiTextStyles.bodySmall.copyWith(color: MeiColors.error),
                ),
              ),
            ],
          ),
          const Gap(MeiSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetry,
              child: Text(ref.tr('try_again')),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
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

String _formatSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}
