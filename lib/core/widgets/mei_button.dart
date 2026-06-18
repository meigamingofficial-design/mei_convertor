import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/theme.dart';

/// Primary action button with scale press animation
class MeiButton extends StatefulWidget {
  const MeiButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  State<MeiButton> createState() => _MeiButtonState();
}

class _MeiButtonState extends State<MeiButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.backgroundColor ?? Theme.of(context).colorScheme.primary;
    final fg = widget.foregroundColor ?? Theme.of(context).colorScheme.onPrimary;
    final isEnabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: isEnabled && !widget.isLoading
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: isEnabled && !widget.isLoading
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: isEnabled && !widget.isLoading
          ? () => setState(() => _isPressed = false)
          : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: 52,
          decoration: BoxDecoration(
            color: !isEnabled ? MeiColors.gray300 : bg,
            borderRadius: MeiRadius.mdAll,
            boxShadow: !isEnabled
                ? MeiShadows.none
                : (_isPressed ? MeiShadows.none : MeiShadows.soft),
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: fg, size: 18),
                        const SizedBox(width: MeiSpacing.sm),
                      ],
                      Text(
                        widget.label,
                        style: MeiTextStyles.labelLarge.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
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

/// Icon-only action button (round)
class MeiIconButton extends StatefulWidget {
  const MeiIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.backgroundColor,
    this.iconColor,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? tooltip;

  @override
  State<MeiIconButton> createState() => _MeiIconButtonState();
}

class _MeiIconButtonState extends State<MeiIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    Widget button = GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled
          ? (_) {
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: !isEnabled
                ? MeiColors.gray200
                : (widget.backgroundColor ?? MeiColors.gray100),
            borderRadius: BorderRadius.circular(widget.size / 2.5),
            boxShadow:
                !isEnabled || _isPressed ? MeiShadows.none : MeiShadows.soft,
          ),
          child: Icon(
            widget.icon,
            size: widget.size * 0.45,
            color: !isEnabled
                ? MeiColors.textTertiary
                : (widget.iconColor ?? MeiColors.textPrimary),
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }

    return button;
  }
}

/// Outlined secondary button
class MeiOutlinedButton extends StatelessWidget {
  const MeiOutlinedButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.width,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
        label: Text(label),
      ),
    );
  }
}

/// Floating action chip — for conversion suggestions
class MeiActionChip extends StatelessWidget {
  const MeiActionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.isSelected = false,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? MeiColors.sakura;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accent : MeiColors.white,
          borderRadius: MeiRadius.fullAll,
          border: Border.all(
            color: isSelected ? accent : MeiColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected ? MeiShadows.soft : MeiShadows.none,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? MeiColors.white : MeiColors.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: MeiTextStyles.labelMedium.copyWith(
                color: isSelected ? MeiColors.white : MeiColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .scale(begin: const Offset(0.9, 0.9), duration: 300.ms, curve: Curves.easeOutBack);
  }
}
