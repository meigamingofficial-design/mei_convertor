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
        overlayColor: WidgetStateProperty.all(Colors.white.withValues(alpha: 0.08)),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient ??
                const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFCE5580), // deep sakura
                    Color(0xFFAA5AA8), // violet-pink
                    Color(0xFF7B70C0), // lavender
                    Color(0xFF5B8FC8), // sky
                  ],
                  stops: [0.0, 0.33, 0.66, 1.0],
                ),
            borderRadius: effectiveBorderRadius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x38C05A82),
                blurRadius: 32,
                offset: Offset(0, 12),
                spreadRadius: -4,
              ),
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: effectiveBorderRadius,
            child: Stack(
              children: [
                // Decorative circle — top right
                Positioned(
                  top: -48,
                  right: -32,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                ),
                // Decorative circle — bottom left
                Positioned(
                  bottom: -24,
                  left: -24,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                ),
                // Decorative circle — mid right
                Positioned(
                  top: 24,
                  right: 70,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: padding ?? MeiSpacing.cardPaddingLg,
                  child: child,
                ),
              ],
            ),
          ),
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
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accentBackground,
                widget.accentBackground.withValues(alpha: 0.5),
                MeiColors.white,
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
            borderRadius: MeiRadius.lgAll,
            border: Border.all(
              color: widget.accentColor.withValues(alpha: _isPressed ? 0.22 : 0.13),
              width: 1.2,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 7),
                      spreadRadius: -3,
                    ),
                    const BoxShadow(
                      color: Color(0x06000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          widget.accentColor,
                          widget.accentColor.withValues(alpha: 0.78),
                        ],
                      ),
                      borderRadius: MeiRadius.mdAll,
                      boxShadow: [
                        BoxShadow(
                          color: widget.accentColor.withValues(alpha: 0.38),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  if (widget.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(alpha: 0.12),
                        borderRadius: MeiRadius.fullAll,
                        border: Border.all(
                          color: widget.accentColor.withValues(alpha: 0.22),
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
              const SizedBox(height: 3),
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
              // Arrow affordance
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.12),
                    borderRadius: MeiRadius.fullAll,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: widget.accentColor,
                    size: 14,
                  ),
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
