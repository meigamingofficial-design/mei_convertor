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
import '../../../core/widgets/mei_card.dart';
import '../../../routing/app_router.dart';
import '../../quick_convert/providers/quick_convert_provider.dart';

/// Interactive Quick Convert widget embedded directly on the home screen dashboard
class HomeQuickConvertHero extends ConsumerStatefulWidget {
  const HomeQuickConvertHero({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  ConsumerState<HomeQuickConvertHero> createState() => _HomeQuickConvertHeroState();
}

class _HomeQuickConvertHeroState extends ConsumerState<HomeQuickConvertHero> {
  bool _pressed = false;

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

    final isResizeSelected = selectedConversion == 'resize';

    return MeiHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MeiSpacing.md,
                  vertical: MeiSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: MeiRadius.fullAll,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Gap(MeiSpacing.xs),
                    Text(
                      ref.tr('home_quick_title'),
                      style: MeiTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.sourcePath != null)
                IconButton(
                  icon: Icon(Icons.refresh_rounded, size: 20, color: Colors.white.withValues(alpha: 0.85)),
                  onPressed: notifier.reset,
                  tooltip: ref.tr('clear_all'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),

          const Gap(MeiSpacing.lg),

          if (state.sourcePath == null) ...[
            // Drop zone/Selector when no file is picked
            GestureDetector(
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) {
                setState(() => _pressed = false);
                _pickFile(notifier);
              },
              onTapCancel: () => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: MeiSpacing.xl),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: MeiRadius.lgAll,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: MeiRadius.mdAll,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: Colors.white.withValues(alpha: 0.9),
                          size: 26,
                        ),
                      ),
                      const Gap(MeiSpacing.md),
                      Text(
                        ref.tr('quick_empty'),
                        style: MeiTextStyles.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Gap(4),
                      Text(
                        ref.tr('quick_empty_sub'),
                        style: MeiTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.70),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            // File chosen details
            Container(
              padding: const EdgeInsets.all(MeiSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: MeiRadius.lgAll,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: MeiRadius.mdAll,
                    ),
                    child: Center(
                      child: Text(
                        state.sourcePath!.split('.').last.toUpperCase(),
                        style: MeiTextStyles.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
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
                          state.sourcePath!.split('/').last,
                          style: MeiTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (detectedType != null) ...[
                          const Gap(2),
                          Text(
                            detectedType.displayName,
                            style: MeiTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.70),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: Colors.white.withValues(alpha: 0.80)),
                    onPressed: notifier.reset,
                  ),
                ],
              ),
            ),

            if (detectedType != null && detectedType.isSupported && !done && !failed && !converting) ...[
              const Gap(MeiSpacing.md),
              Text(
                ref.tr('quick_label_convert_to'),
                style: MeiTextStyles.labelMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Gap(MeiSpacing.sm),
              Wrap(
                spacing: MeiSpacing.xs,
                runSpacing: MeiSpacing.xs,
                children: detectedType.availableConversions.map((conversion) {
                  final isSelected = selectedConversion == conversion;
                  final isSpecial = conversion == 'resize' || conversion == 'compress';
                  return ChoiceChip(
                    label: Text(_labelForConversion(conversion, ref)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        notifier.setTargetFormat(conversion);
                      }
                    },
                    selectedColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    labelStyle: MeiTextStyles.labelSmall.copyWith(
                      color: isSelected
                          ? MeiColors.sakuraDeep
                          : (isSpecial
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.80)),
                      fontWeight: isSelected || isSpecial ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: isSelected ? 0 : 0.30),
                      ),
                    ),
                    showCheckmark: false,
                  );
                }).toList(),
              ),
            ],

            if (isResizeSelected) ...[
              const Gap(MeiSpacing.md),
              Container(
                padding: const EdgeInsets.all(MeiSpacing.md),
                decoration: BoxDecoration(
                  color: MeiColors.sakuraDeep.withValues(alpha: 0.15),
                  borderRadius: MeiRadius.lgAll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ref.tr('quick_resize_warning_sub'),
                      style: MeiTextStyles.bodySmall.copyWith(color: MeiColors.textPrimary),
                    ),
                    const Gap(MeiSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('${MeiRoutes.imageTools}?tab=resize'),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(ref.tr('quick_resize_btn')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MeiColors.sakuraDeep,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (selectedConversion != null && !isResizeSelected && !done && !failed && !converting) ...[
              const Gap(MeiSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: notifier.convert,
                  icon: const Icon(Icons.transform_rounded, size: 16),
                  label: Text(ref.tr('quick_btn_convert').replaceAll('{format}', _formatLabel(selectedConversion, ref))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: MeiColors.sakuraDeep,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: MeiTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
                    shadowColor: Colors.black.withValues(alpha: 0.15),
                    elevation: 2,
                  ),
                ),
              ),
            ],

            if (converting) ...[
              const Gap(MeiSpacing.lg),
              ClipRRect(
                borderRadius: MeiRadius.fullAll,
                child: LinearProgressIndicator(
                  color: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  minHeight: 5,
                ),
              ),
              const Gap(MeiSpacing.xs),
              Center(
                child: Text(
                  ref.tr('quick_btn_converting'),
                  style: MeiTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],

            if (done && outputPath != null) ...[
              const Gap(MeiSpacing.lg),
              Container(
                padding: const EdgeInsets.all(MeiSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: MeiRadius.lgAll,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white.withValues(alpha: 0.9), size: 20),
                        const Gap(MeiSpacing.sm),
                        Expanded(
                          child: Text(
                            ref.tr('quick_success'),
                            style: MeiTextStyles.titleMedium.copyWith(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const Gap(MeiSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => SharingService.openFile(outputPath),
                            icon: const Icon(Icons.open_in_new_rounded, size: 14),
                            label: Text(ref.tr('open')),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                            ),
                          ),
                        ),
                        const Gap(MeiSpacing.sm),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => SharingService.shareFile(outputPath),
                            icon: const Icon(Icons.share_rounded, size: 14),
                            label: Text(ref.tr('share')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: MeiColors.sakuraDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(MeiSpacing.sm),
                    TextButton(
                      onPressed: notifier.reset,
                      child: Text(
                        ref.tr('convert_another_file'),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.80)),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (failed && errorMessage != null) ...[
              const Gap(MeiSpacing.lg),
              Container(
                padding: const EdgeInsets.all(MeiSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: MeiRadius.lgAll,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: Colors.white.withValues(alpha: 0.9), size: 20),
                        const Gap(MeiSpacing.sm),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: MeiTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Gap(MeiSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: notifier.convert,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                            ),
                            child: Text(ref.tr('try_again')),
                          ),
                        ),
                        const Gap(MeiSpacing.sm),
                        Expanded(
                          child: TextButton(
                            onPressed: notifier.reset,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white.withValues(alpha: 0.75),
                            ),
                            child: Text(ref.tr('cancel')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 200.ms)
        .slideY(begin: 0.1, end: 0, duration: 500.ms, delay: 200.ms, curve: Curves.easeOutCubic);
  }

  Future<void> _pickFile(QuickConvertNotifier notifier) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif', 'heic',
        'pdf', 'txt', 'docx', 'doc',
      ],
    );
    if (result?.paths.isNotEmpty == true) {
      final path = result!.paths.first;
      if (path != null) {
        await notifier.setSource(path);
      }
    }
  }

  String _formatLabel(String fmt, WidgetRef ref) {
    switch (fmt) {
      case 'compress':
        return ref.tr('pdf_tab_compress');
      default:
        return fmt.toUpperCase();
    }
  }

  String _labelForConversion(String conversion, WidgetRef ref) => switch (conversion) {
        'compress' => ref.tr('pdf_tab_compress'),
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
}
