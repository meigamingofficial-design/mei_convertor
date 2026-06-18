import 'package:flutter/material.dart';

import '../../core/theme/mei_colors.dart';

/// A chip that shows a file's format extension badge (e.g. "PNG", "PDF").
class FormatBadge extends StatelessWidget {
  const FormatBadge({
    required this.format,
    super.key,
    this.size = 12,
  });

  final String format;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _colorForFormat(format);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        format.toUpperCase(),
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _colorForFormat(String fmt) => switch (fmt.toLowerCase()) {
        'jpg' || 'jpeg' => const Color(0xFFFF7043),
        'png'           => const Color(0xFF42A5F5),
        'webp'          => const Color(0xFF26A69A),
        'bmp'           => const Color(0xFF7E57C2),
        'pdf'           => const Color(0xFFEF5350),
        'txt'           => const Color(0xFF66BB6A),
        'md'            => const Color(0xFF29B6F6),
        _               => MeiColors.lavender,
      };
}

/// A progress indicator with a label, used during conversions.
class MeiProgressIndicator extends StatelessWidget {
  const MeiProgressIndicator({
    required this.label,
    super.key,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator.adaptive(),
        const SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Pill-shaped format selector row.
class FormatSelectorRow extends StatelessWidget {
  const FormatSelectorRow({
    required this.formats,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<String> formats;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: formats.map((fmt) {
          final isSelected = fmt == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(fmt.toUpperCase()),
              selected: isSelected,
              onSelected: (_) => onSelect(fmt),
              selectedColor: cs.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
