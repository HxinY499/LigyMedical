import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 一组可点的小胶囊。选中态走品牌色浅底 + 品牌色字。
class ChoiceChips extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.labels,
    required this.onTap,
    this.selected,
    this.highlighted,
  });

  final List<String> labels;
  final ValueChanged<String> onTap;
  final String? selected;

  /// 未选中时用虚线描边提示「建议选这个」。
  final String? highlighted;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          AppChip(
            label: label,
            selected: label == selected,
            suggested: label == highlighted && label != selected,
            onTap: () => onTap(label),
          ),
      ],
    );
  }
}

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.suggested = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool suggested;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.primary : colors.ink;
    return Material(
      color: selected ? colors.primarySoft : colors.surface,
      shape: StadiumBorder(
        side: suggested
            ? BorderSide(color: colors.primary, width: 1.2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        highlightColor: colors.pressed,
        splashColor: colors.ripple,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
