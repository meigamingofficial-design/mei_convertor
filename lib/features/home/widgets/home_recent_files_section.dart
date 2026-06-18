import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/models/conversion_record.dart';
import '../../../core/services/sharing/sharing_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/mei_states.dart';
import '../../recent_files/providers/history_provider.dart';

/// Recent files section on the home screen — connected to live history data.
class HomeRecentFilesSection extends ConsumerWidget {
  const HomeRecentFilesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return historyAsync.when(
      loading: () => const MeiShimmerList(itemCount: 3),
      error: (err, stack) => const SizedBox.shrink(),
      data: (records) {
        if (records.isEmpty) {
          return const _RecentFilesEmpty();
        }
        final shown = records.take(3).toList();
        return Container(
          decoration: BoxDecoration(
            color: MeiColors.white,
            borderRadius: MeiRadius.lgAll,
            border: Border.all(color: MeiColors.border),
          ),
          child: Column(
            children: shown.asMap().entries.map((e) {
              final index = e.key;
              final record = e.value;
              return Column(
                children: [
                  RecentFileTile(
                    record: record,
                    onTap: () => SharingService.openFile(record.outputPath),
                  ).animate().fadeIn(
                        duration: 350.ms,
                        delay: (index * 80 + 200).ms,
                      ),
                  if (index < shown.length - 1)
                    const Divider(height: 1, indent: MeiSpacing.lg),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _RecentFilesEmpty extends ConsumerWidget {
  const _RecentFilesEmpty();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: MeiSpacing.xxl,
        horizontal: MeiSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: MeiColors.white,
        borderRadius: MeiRadius.lgAll,
        border: Border.all(color: MeiColors.border, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: MeiColors.convertPurpleLight,
              borderRadius: MeiRadius.lgAll,
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              size: 28,
              color: MeiColors.convertPurple,
            ),
          ),
          const Gap(MeiSpacing.lg),
          Text(ref.tr('recent_empty'), style: MeiTextStyles.titleLarge),
          const Gap(MeiSpacing.xs),
          Text(
            ref.tr('recent_empty_sub'),
            style: MeiTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms, delay: 300.ms)
        .slideY(
          begin: 0.1,
          end: 0,
          duration: 500.ms,
          delay: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

/// Reusable recent file tile — used both on home and in recent files screen
class RecentFileTile extends ConsumerWidget {
  const RecentFileTile({
    super.key,
    required this.record,
    this.onTap,
  });

  final ConversionRecord record;
  final VoidCallback? onTap;

  Color get _accentColor {
    if (record.isImage) return MeiColors.imageBlue;
    if (record.isPdf) return MeiColors.pdfRed;
    return MeiColors.docGreen;
  }

  Color get _bgColor {
    if (record.isImage) return MeiColors.imageBlueLight;
    if (record.isPdf) return MeiColors.pdfRedLight;
    return MeiColors.docGreenLight;
  }

  IconData get _icon {
    if (record.isImage) return Icons.image_rounded;
    if (record.isPdf) return Icons.picture_as_pdf_rounded;
    return Icons.description_rounded;
  }

  String _formatTime(DateTime dt, WidgetRef ref) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return ref.tr('recent_just_now');
    if (diff.inHours < 1) return ref.tr('recent_m_ago').replaceAll('{count}', '${diff.inMinutes}');
    if (diff.inHours < 24) return ref.tr('recent_h_ago').replaceAll('{count}', '${diff.inHours}');
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: MeiRadius.mdAll,
        overlayColor: WidgetStateProperty.all(
            MeiColors.sakura.withValues(alpha: 0.05)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: MeiSpacing.sm,
            horizontal: MeiSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: MeiRadius.mdAll,
                ),
                child: Icon(_icon, color: _accentColor, size: 20),
              ),
              const Gap(MeiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.outputFileName,
                      style: MeiTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(MeiSpacing.xxs),
                    Text(
                      '${record.inputFormat.toUpperCase()} → ${record.outputFormat.toUpperCase()} • ${record.displaySize}',
                      style: MeiTextStyles.bodySmall,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Text(_formatTime(record.convertedAt, ref), style: MeiTextStyles.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
