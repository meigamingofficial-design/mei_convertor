import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/locale_provider.dart';
import '../../../core/models/conversion_record.dart';
import '../../../core/services/sharing/sharing_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/mei_card.dart';
import '../../../core/widgets/mei_states.dart';
import '../../../routing/app_router.dart';
import '../providers/history_provider.dart';

class RecentFilesScreen extends ConsumerWidget {
  const RecentFilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: MeiColors.offWhite,
      appBar: AppBar(
        title: Text(ref.tr('recent_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          historyAsync.when(
            data: (records) => records.isEmpty
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: () => _confirmClearAll(context, ref),
                    style: TextButton.styleFrom(
                        foregroundColor: MeiColors.error),
                    child: Text(ref.tr('clear_all')),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(MeiSpacing.lg),
          child: MeiShimmerList(itemCount: 6),
        ),
        error: (e, _) => Center(
          child: Text('${ref.tr('error')}: $e',
              style: MeiTextStyles.bodyMedium),
        ),
        data: (records) {
          if (records.isEmpty) {
            return MeiEmptyState(
              icon: Icons.history_rounded,
              title: ref.tr('recent_empty'),
              subtitle: ref.tr('recent_empty_sub'),
              actionLabel: ref.tr('recent_start_converting'),
              action: () => context.push(MeiRoutes.quickConvert),
              accentColor: MeiColors.convertPurpleDeep,
              accentBackground: MeiColors.convertPurpleLight,
            );
          }
          return _RecordsList(records: records);
        },
      ),
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ref.tr('recent_clear_all_title')),
        content: Text(ref.tr('recent_clear_all_desc')),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: Text(ref.tr('cancel')),
          ),
          TextButton(
            onPressed: () => ctx.pop(true),
            style: TextButton.styleFrom(foregroundColor: MeiColors.error),
            child: Text(ref.tr('clear_all')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(historyProvider.notifier).clearAll();
    }
  }
}

// ── Grouped list ───────────────────────────────────────────────────────────────

class _RecordsList extends ConsumerWidget {
  const _RecordsList({required this.records});
  final List<ConversionRecord> records;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = _groupByDate(records, ref);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        MeiSpacing.lg,
        MeiSpacing.sm,
        MeiSpacing.lg,
        MeiSpacing.massive,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped[index];
        if (entry is _DateHeader) {
          return Padding(
            padding: const EdgeInsets.only(
              top: MeiSpacing.lg,
              bottom: MeiSpacing.sm,
            ),
            child: Text(
              entry.label,
              style: MeiTextStyles.labelMedium.copyWith(
                color: MeiColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        final record = (entry as _RecordItem).record;
        return Padding(
          padding: const EdgeInsets.only(bottom: MeiSpacing.sm),
          child: _RecordTile(record: record)
              .animate()
              .fadeIn(duration: 300.ms, delay: (index * 30).ms)
              .slideX(
                  begin: 0.04,
                  end: 0,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic),
        );
      },
    );
  }

  List<Object> _groupByDate(List<ConversionRecord> records, WidgetRef ref) {
    final result = <Object>[];
    String? lastLabel;

    for (final record in records) {
      final label = _dateLabel(record.convertedAt, ref);
      if (label != lastLabel) {
        result.add(_DateHeader(label));
        lastLabel = label;
      }
      result.add(_RecordItem(record));
    }
    return result;
  }

  String _dateLabel(DateTime dt, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return ref.tr('recent_today');
    if (diff == 1) return ref.tr('recent_yesterday');
    if (diff < 7) return ref.tr('recent_this_week');
    return ref.tr('recent_earlier');
  }
}

class _DateHeader {
  const _DateHeader(this.label);
  final String label;
}

class _RecordItem {
  const _RecordItem(this.record);
  final ConversionRecord record;
}

// ── Record tile with swipe to delete ──────────────────────────────────────────

class _RecordTile extends ConsumerWidget {
  const _RecordTile({required this.record});
  final ConversionRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: MeiSpacing.xl),
        decoration: const BoxDecoration(
          color: MeiColors.error,
          borderRadius: MeiRadius.lgAll,
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      onDismissed: (_) =>
          ref.read(historyProvider.notifier).remove(record.id),
      child: GestureDetector(
        onLongPress: () => _showOptions(context, ref),
        child: MeiCard(
          padding: const EdgeInsets.all(MeiSpacing.md),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: MeiRadius.mdAll,
                ),
                child: Icon(_icon, color: _accentColor, size: 22),
              ),
              const Gap(MeiSpacing.md),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.outputFileName,
                      style: MeiTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(3),
                    Row(
                      children: [
                        _Badge(
                          label: record.inputFormat.toUpperCase(),
                          color: _accentColor,
                          bg: _bgColor,
                        ),
                        const Gap(4),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 12, color: MeiColors.textTertiary),
                        const Gap(4),
                        _Badge(
                          label: record.outputFormat.toUpperCase(),
                          color: _accentColor,
                          bg: _bgColor,
                        ),
                        const Gap(MeiSpacing.sm),
                        Text(
                          record.displaySize,
                          style: MeiTextStyles.labelSmall.copyWith(
                            color: MeiColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    Text(
                      _formatTime(record.convertedAt, ref),
                      style: MeiTextStyles.labelSmall.copyWith(
                        color: MeiColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Action icon
              IconButton(
                onPressed: () => _showOptions(context, ref),
                icon: const Icon(Icons.more_vert_rounded,
                    size: 18, color: MeiColors.textTertiary),
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

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

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  MeiSpacing.lg, MeiSpacing.md, MeiSpacing.lg, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      record.outputFileName,
                      style: MeiTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            _OptionTile(
              icon: Icons.open_in_new_rounded,
              label: ref.tr('recent_open_file'),
              onTap: () {
                ctx.pop();
                SharingService.openFile(record.outputPath);
              },
            ),
            _OptionTile(
              icon: Icons.share_rounded,
              label: ref.tr('recent_share_file'),
              onTap: () {
                ctx.pop();
                SharingService.shareFile(record.outputPath,
                    subject: record.outputFileName);
              },
            ),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: ref.tr('recent_delete_record'),
              color: MeiColors.error,
              onTap: () {
                ctx.pop();
                ref.read(historyProvider.notifier).remove(record.id);
              },
            ),
            const Gap(MeiSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, required this.bg});
  final String label;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: MeiRadius.fullAll,
      ),
      child: Text(
        label,
        style: MeiTextStyles.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color ?? MeiColors.textPrimary, size: 22),
      title: Text(
        label,
        style: MeiTextStyles.bodyMedium.copyWith(
          color: color ?? MeiColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
