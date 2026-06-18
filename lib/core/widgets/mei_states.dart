import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/theme.dart';

/// Skeleton shimmer loading for card-shaped items
class MeiShimmerCard extends StatelessWidget {
  const MeiShimmerCard({
    super.key,
    this.height = 80,
    this.width,
    this.borderRadius,
  });

  final double height;
  final double? width;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: MeiColors.gray100,
      highlightColor: MeiColors.white,
      period: const Duration(milliseconds: 1200),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: MeiColors.gray100,
          borderRadius: borderRadius ?? MeiRadius.lgAll,
        ),
      ),
    );
  }
}

/// Shimmer loading for the recent files list
class MeiShimmerList extends StatelessWidget {
  const MeiShimmerList({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: MeiSpacing.sm),
          child: Shimmer.fromColors(
            baseColor: MeiColors.gray100,
            highlightColor: MeiColors.white,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: MeiColors.gray100,
                    borderRadius: MeiRadius.mdAll,
                  ),
                ),
                const SizedBox(width: MeiSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: MeiColors.gray100,
                          borderRadius: MeiRadius.smAll,
                        ),
                      ),
                      const SizedBox(height: MeiSpacing.xs),
                      Container(
                        height: 11,
                        width: 120,
                        decoration: const BoxDecoration(
                          color: MeiColors.gray100,
                          borderRadius: MeiRadius.smAll,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty state widget with icon and message
class MeiEmptyState extends StatelessWidget {
  const MeiEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.accentColor,
    this.accentBackground,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? action;
  final String? actionLabel;
  final Color? accentColor;
  final Color? accentBackground;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MeiSpacing.massive),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accentBackground ?? MeiColors.gray100,
                borderRadius: MeiRadius.xlAll,
              ),
              child: Icon(
                icon,
                size: 32,
                color: accentColor ?? MeiColors.gray400,
              ),
            ),
            const SizedBox(height: MeiSpacing.xl),
            Text(
              title,
              style: MeiTextStyles.headlineSmall.copyWith(
                color: MeiColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: MeiSpacing.sm),
              Text(
                subtitle!,
                style: MeiTextStyles.bodyMedium.copyWith(
                  color: MeiColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: MeiSpacing.xxl),
              ElevatedButton(
                onPressed: action,
                style: accentColor != null ? ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                ) : null,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Section header widget
class MeiSectionHeader extends StatelessWidget {
  const MeiSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding,
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: MeiTextStyles.headlineSmall),
          ?trailing,
        ],
      ),
    );
  }
}

/// Divider with label
class MeiLabelDivider extends StatelessWidget {
  const MeiLabelDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: MeiColors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: MeiSpacing.sm),
          child: Text(
            label,
            style: MeiTextStyles.labelSmall,
          ),
        ),
        const Expanded(child: Divider(color: MeiColors.divider)),
      ],
    );
  }
}
