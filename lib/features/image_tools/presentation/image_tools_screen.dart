import 'dart:io';

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
import '../providers/image_tools_provider.dart';

class ImageToolsScreen extends ConsumerStatefulWidget {
  const ImageToolsScreen({
    super.key,
    this.initialTabName,
  });

  final String? initialTabName;

  @override
  ConsumerState<ImageToolsScreen> createState() => _ImageToolsScreenState();
}

class _ImageToolsScreenState extends ConsumerState<ImageToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int _tabIndexFor(String? tabName) {
    if (tabName == null) return 0;
    switch (tabName) {
      case 'convert':
        return 0;
      case 'compress':
        return 1;
      case 'resize':
        return 2;
      default:
        return 0;
    }
  }

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabIndexFor(widget.initialTabName);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tabs = [
          ImageToolsTab.convert,
          ImageToolsTab.compress,
          ImageToolsTab.resize,
        ];
        ref.read(imageToolsProvider.notifier).setTab(tabs[_tabController.index]);
      }
    });

    if (widget.initialTabName != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tabs = [
          ImageToolsTab.convert,
          ImageToolsTab.compress,
          ImageToolsTab.resize,
        ];
        ref.read(imageToolsProvider.notifier).setTab(tabs[initialIndex]);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageToolsProvider);

    return Scaffold(
      backgroundColor: MeiColors.offWhite,
      appBar: AppBar(
        title: Text(ref.tr('image_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: MeiColors.imageBlueDeep,
          unselectedLabelColor: MeiColors.textTertiary,
          indicatorColor: MeiColors.imageBlueDeep,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: MeiTextStyles.labelLarge
              .copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: MeiTextStyles.labelLarge,
          tabs: [
            Tab(text: ref.tr('image_tab_convert')),
            Tab(text: ref.tr('image_tab_compress')),
            Tab(text: ref.tr('image_tab_resize')),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: TabBarView(
          controller: _tabController,
          children: [
            _ConvertTab(state: state),
            _CompressTab(state: state),
            _ResizeTab(state: state),
          ],
        ),
      ),
    );
  }
}

// ── Convert Tab ────────────────────────────────────────────────────────────────

class _ConvertTab extends ConsumerWidget {
  const _ConvertTab({required this.state});
  final ImageToolsState state;

  static const _formats = ['jpg', 'png', 'webp', 'bmp'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(imageToolsProvider.notifier);

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
              icon: Icons.add_photo_alternate_rounded,
              title: ref.tr('image_empty_convert'),
              subtitle: ref.tr('image_empty_convert_sub'),
              action: notifier.pickFiles,
              actionLabel: ref.tr('image_btn_select'),
              accentColor: MeiColors.imageBlueDeep,
              accentBackground: MeiColors.imageBlueLight,
            )
          else ...[
            // File picker showing details
            _FilePicker(
              hasFile: state.hasFile,
              label: ref.tr('image_selected_count').replaceAll('{count}', '${state.selectedPaths.length}'),
              sublabel: 'JPG, PNG, WEBP, BMP supported',
              onTap: notifier.pickFiles,
              onRemove: notifier.reset,
              fileSize: _formatTotalSize(state.selectedPaths),
            ),
            const Gap(MeiSpacing.xxl),

            // File chips
            _FileChips(paths: state.selectedPaths),
            const Gap(MeiSpacing.xxl),

            // Format selector
            Text(ref.tr('quick_label_convert_to'), style: MeiTextStyles.headlineSmall),
            const Gap(MeiSpacing.md),
            Wrap(
              spacing: MeiSpacing.sm,
              runSpacing: MeiSpacing.sm,
              children: _formats.map((fmt) {
                final isSelected = state.outputFormat == fmt;
                return _FormatChip(
                  label: fmt.toUpperCase(),
                  isSelected: isSelected,
                  onTap: () => notifier.setOutputFormat(fmt),
                );
              }).toList(),
            ),
            const Gap(MeiSpacing.xxl),

            // Convert button
            if (state.status != ImageToolsStatus.done)
              MeiButton(
                label: state.isBusy
                    ? ref.tr('quick_btn_converting')
                    : ref.tr('quick_btn_convert').replaceAll('{format}', state.outputFormat.toUpperCase()),
                icon: Icons.transform_rounded,
                onPressed: state.isBusy ? null : notifier.convert,
                isLoading: state.isBusy,
                width: double.infinity,
                backgroundColor: MeiColors.imageBlueDeep,
              ),
          ],

          // Progress
          if (state.isBusy) ...[
            const Gap(MeiSpacing.lg),
            ClipRRect(
              borderRadius: MeiRadius.smAll,
              child: LinearProgressIndicator(
                value: state.progress > 0 ? state.progress : null,
                minHeight: 4,
              ),
            ),
          ],

          // Result
          if (state.status == ImageToolsStatus.done && state.outputPath != null)
            _ResultCard(
              outputPath: state.outputPath!,
              originalPaths: state.selectedPaths,
              onReset: notifier.convertAnother,
            ),

          // Error
          if (state.status == ImageToolsStatus.failed && state.failure != null)
            _ErrorCard(message: state.failure!.message),

          const Gap(MeiSpacing.massive),
        ],
      ),
    );
  }
}

// ── Compress Tab ───────────────────────────────────────────────────────────────

class _CompressTab extends ConsumerWidget {
  const _CompressTab({required this.state});
  final ImageToolsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(imageToolsProvider.notifier);
    final quality = state.quality;

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
              icon: Icons.compress_rounded,
              title: ref.tr('image_empty_compress'),
              subtitle: ref.tr('image_empty_compress_sub'),
              action: notifier.pickFiles,
              actionLabel: ref.tr('image_btn_select'),
              accentColor: MeiColors.imageBlueDeep,
              accentBackground: MeiColors.imageBlueLight,
            )
          else ...[
            _FilePicker(
              hasFile: state.hasFile,
              label: state.primaryPath.split('/').last,
              sublabel: ref.tr('image_tab_compress'),
              onTap: notifier.pickFiles,
              onRemove: notifier.reset,
              fileSize: _getFileSize(state.primaryPath),
              dimensions: state.sourceWidth != null
                  ? '${state.sourceWidth} × ${state.sourceHeight} px'
                  : null,
            ),
            const Gap(MeiSpacing.xxl),

            // Quality slider
            MeiCard(
              padding: MeiSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ref.tr('image_label_quality'), style: MeiTextStyles.titleMedium),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: const BoxDecoration(
                          color: MeiColors.imageBlueLight,
                          borderRadius: MeiRadius.fullAll,
                        ),
                        child: Text(
                          '$quality%',
                          style: MeiTextStyles.labelLarge.copyWith(
                            color: MeiColors.imageBlueDeep,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: MeiColors.imageBlueDeep,
                      inactiveTrackColor: MeiColors.imageBlueLight,
                      thumbColor: MeiColors.imageBlueDeep,
                      overlayColor: MeiColors.imageBlueDeep.withAlpha(30),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: quality.toDouble(),
                      min: 10,
                      max: 100,
                      divisions: 18,
                      onChanged: (v) => notifier.setQuality(v.round()),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ref.tr('image_quality_smaller'),
                          style: MeiTextStyles.bodySmall
                              .copyWith(color: MeiColors.textTertiary)),
                      Text(ref.tr('image_quality_better'),
                          style: MeiTextStyles.bodySmall
                              .copyWith(color: MeiColors.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(MeiSpacing.xxl),

            if (state.status != ImageToolsStatus.done)
              MeiButton(
                label: state.isBusy ? ref.tr('pdf_btn_compressing') : ref.tr('image_btn_compress'),
                icon: Icons.compress_rounded,
                onPressed: state.isBusy ? null : notifier.compress,
                isLoading: state.isBusy,
                width: double.infinity,
                backgroundColor: MeiColors.imageBlueDeep,
              ),
          ],

          if (state.status == ImageToolsStatus.done && state.outputPath != null)
            _ResultCard(
              outputPath: state.outputPath!,
              originalPaths: state.selectedPaths,
              onReset: notifier.convertAnother,
            ),

          if (state.status == ImageToolsStatus.failed && state.failure != null)
            _ErrorCard(message: state.failure!.message),

          const Gap(MeiSpacing.massive),
        ],
      ),
    );
  }
}

// ── Resize Tab ─────────────────────────────────────────────────────────────────

class _ResizeTab extends ConsumerStatefulWidget {
  const _ResizeTab({required this.state});
  final ImageToolsState state;

  @override
  ConsumerState<_ResizeTab> createState() => _ResizeTabState();
}

class _ResizeTabState extends ConsumerState<_ResizeTab> {
  final _widthCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  bool _syncing = false;

  @override
  void didUpdateWidget(_ResizeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final s = widget.state;
    if (s.targetWidth != null && !_syncing) {
      _widthCtrl.text = '${s.targetWidth}';
    }
    if (s.targetHeight != null && !_syncing) {
      _heightCtrl.text = '${s.targetHeight}';
    }
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final notifier = ref.read(imageToolsProvider.notifier);

    final wStr = _widthCtrl.text;
    final hStr = _heightCtrl.text;
    final wVal = int.tryParse(wStr);
    final hVal = int.tryParse(hStr);

    String? widthError;
    String? heightError;
    String? sizeWarning;

    if (state.hasFile) {
      if (wStr.isEmpty || wVal == null || wVal < 1) {
        widthError = ref.tr('image_error_width_empty');
      } else if (state.sourceWidth != null && wVal > state.sourceWidth!) {
        widthError = ref.tr('image_error_width_max').replaceAll('{max}', '${state.sourceWidth}');
      }

      if (hStr.isEmpty || hVal == null || hVal < 1) {
        heightError = ref.tr('image_error_height_empty');
      } else if (state.sourceHeight != null && hVal > state.sourceHeight!) {
        heightError = ref.tr('image_error_height_max').replaceAll('{max}', '${state.sourceHeight}');
      }

      if (widthError == null && heightError == null) {
        if ((wVal != null && wVal < 50) || (hVal != null && hVal < 50)) {
          sizeWarning = ref.tr('image_warning_quality');
        }
      }
    }

    final isValid = state.hasFile && widthError == null && heightError == null;

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
              icon: Icons.aspect_ratio_rounded,
              title: ref.tr('image_empty_resize'),
              subtitle: ref.tr('image_empty_resize_sub'),
              action: notifier.pickFiles,
              actionLabel: ref.tr('image_btn_select'),
              accentColor: MeiColors.imageBlueDeep,
              accentBackground: MeiColors.imageBlueLight,
            )
          else ...[
            _FilePicker(
              hasFile: state.hasFile,
              label: state.primaryPath.split('/').last,
              sublabel: ref.tr('image_tab_resize'),
              onTap: notifier.pickFiles,
              onRemove: notifier.reset,
              fileSize: _getFileSize(state.primaryPath),
              dimensions: state.sourceWidth != null
                  ? '${state.sourceWidth} × ${state.sourceHeight} px'
                  : null,
            ),
            const Gap(MeiSpacing.xxl),

            MeiCard(
              padding: MeiSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(ref.tr('image_label_dims'),
                          style: MeiTextStyles.titleMedium),
                      GestureDetector(
                        onTap: notifier.toggleAspectLock,
                        child: Row(
                          children: [
                            Text(
                              state.lockAspectRatio ? '🔒' : '🔓',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const Gap(4),
                            Text(
                              ref.tr('image_keep_ratio'),
                              style: MeiTextStyles.labelSmall.copyWith(
                                color: state.lockAspectRatio
                                    ? MeiColors.imageBlueDeep
                                    : MeiColors.textTertiary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap(MeiSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _DimensionField(
                          controller: _widthCtrl,
                          label: ref.tr('image_width'),
                          unit: 'px',
                          errorText: widthError,
                          onChanged: (v) {
                            _syncing = true;
                            notifier.setTargetWidth(int.tryParse(v));
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (state.lockAspectRatio && state.targetHeight != null) {
                                _heightCtrl.text = '${state.targetHeight}';
                              }
                              _syncing = false;
                            });
                          },
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: MeiSpacing.md).copyWith(top: 36),
                        child: Icon(
                          state.lockAspectRatio
                              ? Icons.link_rounded
                              : Icons.link_off_rounded,
                          color: state.lockAspectRatio
                              ? MeiColors.imageBlueDeep
                              : MeiColors.gray300,
                        ),
                      ),
                      Expanded(
                        child: _DimensionField(
                          controller: _heightCtrl,
                          label: ref.tr('image_height'),
                          unit: 'px',
                          errorText: heightError,
                          onChanged: (v) {
                            _syncing = true;
                            notifier.setTargetHeight(int.tryParse(v));
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (state.lockAspectRatio && state.targetWidth != null) {
                                _widthCtrl.text = '${state.targetWidth}';
                              }
                              _syncing = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (sizeWarning != null) ...[
                    const Gap(MeiSpacing.md),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: MeiColors.warning, size: 16),
                        const Gap(6),
                        Expanded(
                          child: Text(
                            sizeWarning,
                            style: MeiTextStyles.bodySmall
                                .copyWith(color: MeiColors.warning),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Gap(MeiSpacing.xxl),

            if (state.status != ImageToolsStatus.done)
              MeiButton(
                label: state.isBusy ? ref.tr('image_btn_resizing') : ref.tr('image_btn_resize'),
                icon: Icons.aspect_ratio_rounded,
                onPressed: (isValid && !state.isBusy) ? notifier.resize : null,
                isLoading: state.isBusy,
                width: double.infinity,
                backgroundColor: MeiColors.imageBlueDeep,
              ),
          ],

          if (state.status == ImageToolsStatus.done && state.outputPath != null)
            _ResultCard(
              outputPath: state.outputPath!,
              originalPaths: state.selectedPaths,
              onReset: notifier.convertAnother,
              isResize: true,
              targetWidth: state.targetWidth,
              targetHeight: state.targetHeight,
            ),

          if (state.status == ImageToolsStatus.failed && state.failure != null)
            _ErrorCard(message: state.failure!.message),

          const Gap(MeiSpacing.massive),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

// ── Helper functions for sizes ──────────────────────────────────────────────────

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

String _formatTotalSize(List<String> paths) {
  try {
    int totalBytes = 0;
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) {
        totalBytes += f.lengthSync();
      }
    }
    return _formatSize(totalBytes);
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

// ── Shared sub-widgets ─────────────────────────────────────────────────────────

class _FilePicker extends ConsumerStatefulWidget {
  const _FilePicker({
    required this.hasFile,
    required this.label,
    required this.sublabel,
    required this.onTap,
    this.onRemove,
    this.fileSize,
    this.dimensions,
  });

  final bool hasFile;
  final String label;
  final String sublabel;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final String? fileSize;
  final String? dimensions;

  @override
  ConsumerState<_FilePicker> createState() => _FilePickerState();
}

class _FilePickerState extends ConsumerState<_FilePicker> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.hasFile) {
      return GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: MeiColors.white,
              borderRadius: MeiRadius.xlAll,
              border: Border.all(
                color: MeiColors.border,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: MeiColors.gray100,
                    borderRadius: MeiRadius.lgAll,
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 26,
                    color: MeiColors.gray400,
                  ),
                ),
                const Gap(MeiSpacing.md),
                Text(
                  widget.label,
                  style: MeiTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap(4),
                Text(widget.sublabel, style: MeiTextStyles.bodySmall),
              ],
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.08, end: 0, duration: 350.ms, curve: Curves.easeOutCubic);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MeiSpacing.lg),
      decoration: BoxDecoration(
        color: MeiColors.imageBlueLight,
        borderRadius: MeiRadius.xlAll,
        border: Border.all(
          color: MeiColors.imageBlueDeep,
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
                  color: MeiColors.imageBlueDeep.withValues(alpha: 0.15),
                  borderRadius: MeiRadius.mdAll,
                ),
                child: const Icon(
                  Icons.image_rounded,
                  size: 22,
                  color: MeiColors.imageBlueDeep,
                ),
              ),
              const Gap(MeiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: MeiTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Row(
                      children: [
                        if (widget.fileSize != null) ...[
                          Text(widget.fileSize!, style: MeiTextStyles.bodySmall),
                          if (widget.dimensions != null) ...[
                            const Text('  ·  ', style: MeiTextStyles.bodySmall),
                            Text(widget.dimensions!, style: MeiTextStyles.bodySmall),
                          ],
                        ] else ...[
                          Text(widget.sublabel, style: MeiTextStyles.bodySmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(MeiSpacing.md),
          const Divider(color: MeiColors.imageBlue),
          const Gap(MeiSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: widget.onTap,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: MeiColors.imageBlueDeep),
                label: Text(
                  ref.tr('change_file'),
                  style: MeiTextStyles.labelMedium.copyWith(color: MeiColors.imageBlueDeep),
                ),
              ),
              if (widget.onRemove != null)
                TextButton.icon(
                  onPressed: widget.onRemove,
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
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.08, end: 0, duration: 350.ms, curve: Curves.easeOutCubic);
  }
}

class _FileChips extends StatelessWidget {
  const _FileChips({required this.paths});
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MeiSpacing.xs,
      runSpacing: MeiSpacing.xs,
      children: paths
          .take(6)
          .map((p) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: MeiColors.white,
                  borderRadius: MeiRadius.fullAll,
                  border: Border.all(color: MeiColors.border),
                ),
                child: Text(
                  p.split('/').last,
                  style: MeiTextStyles.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
    );
  }
}

class _FormatChip extends StatefulWidget {
  const _FormatChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_FormatChip> createState() => _FormatChipState();
}

class _FormatChipState extends State<_FormatChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected ? MeiColors.imageBlueDeep : MeiColors.white,
            borderRadius: MeiRadius.fullAll,
            border: Border.all(
              color: widget.isSelected ? MeiColors.imageBlueDeep : MeiColors.border,
              width: 1.5,
            ),
            boxShadow:
                widget.isSelected ? MeiShadows.soft : MeiShadows.none,
          ),
          child: Text(
            widget.label,
            style: MeiTextStyles.labelLarge.copyWith(
              color: widget.isSelected
                  ? MeiColors.white
                  : MeiColors.textSecondary,
              fontWeight: widget.isSelected
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard({
    required this.outputPath,
    required this.onReset,
    required this.originalPaths,
    this.isResize = false,
    this.targetWidth,
    this.targetHeight,
  });

  final String outputPath;
  final List<String> originalPaths;
  final VoidCallback onReset;
  final bool isResize;
  final int? targetWidth;
  final int? targetHeight;

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
                  child: const Icon(Icons.check_circle_rounded,
                      color: MeiColors.success, size: 22),
                ),
                const Gap(MeiSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ref.tr('quick_success'),
                          style: MeiTextStyles.titleMedium),
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
            
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatItem(label: ref.tr('original_size'), value: _formatSize(originalSize)),
                _StatItem(label: ref.tr('new_size'), value: _formatSize(convertedSize)),
                if (spaceSaved > 0 && !isResize)
                  _StatItem(label: ref.tr('space_saved'), value: '$spaceSaved%'),
                if (isResize && targetWidth != null && targetHeight != null)
                  _StatItem(label: ref.tr('output_dims'), value: '$targetWidth × $targetHeight'),
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
                      foregroundColor: MeiColors.imageBlueDeep,
                      side: const BorderSide(color: MeiColors.imageBlue),
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
                      backgroundColor: MeiColors.imageBlueDeep,
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
                  foregroundColor: MeiColors.imageBlueDeep,
                  side: const BorderSide(color: MeiColors.imageBlue),
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
                  foregroundColor: MeiColors.imageBlueDeep,
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: MeiSpacing.xxl),
      child: MeiCard(
        padding: MeiSpacing.cardPadding,
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: MeiColors.error, size: 24),
            const Gap(MeiSpacing.md),
            Expanded(
              child: Text(message,
                  style: MeiTextStyles.bodySmall
                      .copyWith(color: MeiColors.error)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DimensionField extends StatelessWidget {
  const _DimensionField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.onChanged,
    this.errorText,
  });
  final TextEditingController controller;
  final String label;
  final String unit;
  final void Function(String) onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: MeiTextStyles.labelMedium),
        const Gap(MeiSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: MeiColors.white,
            borderRadius: MeiRadius.mdAll,
            border: Border.all(color: errorText != null ? MeiColors.error : MeiColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: onChanged,
                  style: MeiTextStyles.bodyMedium,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: MeiSpacing.md, vertical: MeiSpacing.sm),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: MeiSpacing.sm),
                child: Text(
                  unit,
                  style: MeiTextStyles.labelSmall.copyWith(
                    color: errorText != null ? MeiColors.error : MeiColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          const Gap(4),
          Text(
            errorText!,
            style: MeiTextStyles.labelSmall.copyWith(color: MeiColors.error),
          ),
        ],
      ],
    );
  }
}
