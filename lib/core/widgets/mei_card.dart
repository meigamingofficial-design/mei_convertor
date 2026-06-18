import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/theme.dart';

/// Reusable premium Mei card with soft shadow and border
class MeiCard extends StatelessWidget {
  const MeiCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.borderRadius,
    this.shadows,
    this.onTap,
    this.onLongPress,
    this.width,
    this.height,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadows;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;
  final double? height;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? MeiRadius.lgAll;

    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? MeiColors.white,
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: borderColor ?? MeiColors.border,
          width: 1,
        ),
        boxShadow: shadows ?? MeiShadows.soft,
      ),
      clipBehavior: clipBehavior,
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );

    if (onTap != null || onLongPress != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: effectiveBorderRadius,
          overlayColor: WidgetStateProperty.all(
            MeiColors.sakura.withValues(alpha: 0.06),
          ),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Mei hero card — larger accent-colored card for Quick Convert
class MeiHeroCard extends StatelessWidget {
  const MeiHeroCard({
    super.key,
    required this.child,
    this.gradient,
    this.onTap,
    this.padding,
    this.borderRadius,
  });

  final Widget child;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? MeiRadius.xlAll;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveBorderRadius,
        overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.1)),
        child: Container(
          padding: padding ?? MeiSpacing.cardPaddingLg,
          decoration: BoxDecoration(
            gradient: gradient ??
                const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF5D8E3),
                    Color(0xFFEEE5F5),
                    Color(0xFFE8F0FA),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
            borderRadius: effectiveBorderRadius,
            boxShadow: MeiShadows.card,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Feature tile card for home screen grid
class MeiFeatureTile extends StatefulWidget {
  const MeiFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.accentBackground,
    this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color accentBackground;
  final VoidCallback? onTap;
  final String? badge;

  @override
  State<MeiFeatureTile> createState() => _MeiFeatureTileState();
}

class _MeiFeatureTileState extends State<MeiFeatureTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: MeiColors.white,
            borderRadius: MeiRadius.lgAll,
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              const BoxShadow(
                color: Color(0x041C1A18),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.accentBackground,
                          widget.accentBackground.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: MeiRadius.mdAll,
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.15),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 20,
                    ),
                  ),
                  if (widget.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.accentBackground.withValues(alpha: 0.8),
                        borderRadius: MeiRadius.fullAll,
                        border: Border.all(
                          color: widget.accentColor.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.badge!,
                        style: MeiTextStyles.labelSmall.copyWith(
                          color: widget.accentColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: MeiSpacing.md),
              Text(
                widget.title,
                style: MeiTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: MeiColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  widget.subtitle,
                  style: MeiTextStyles.bodySmall.copyWith(
                    color: MeiColors.textSecondary,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

