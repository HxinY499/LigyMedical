import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

enum StatusTone { primary, danger, accent, neutral }

/// 小胶囊状态标签：倒计时、记录类型、异常提示。浅底 + 同色字，扁平。
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.tone = StatusTone.primary,
    this.dense = false,
  });

  final String label;
  final StatusTone tone;

  /// 紧凑档：标题旁的类型标签用，圆角小方块而不是胶囊。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (tone) {
      StatusTone.primary => (colors.primarySoft, colors.primary),
      StatusTone.danger => (colors.dangerSoft, colors.danger),
      // 琥珀字压在琥珀浅底上对比太弱，字往墨色压一档。
      StatusTone.accent => (
        colors.accent.withValues(alpha: colors.isDark ? 0.2 : 0.14),
        colors.isDark ? colors.accent : Color.lerp(colors.accent, colors.ink, 0.3)!,
      ),
      StatusTone.neutral => (colors.fill, colors.muted),
    };
    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(dense ? 6 : 999),
      ),
      child: Text(
        label,
        // 行高钉成 1 且行距上下均分：中文落在西文字体的行框里时，默认把多出的
        // 行距大半分给上方，字会偏下，上留白比下留白大。
        style: TextStyle(
          fontSize: dense ? 11.5 : 12.5,
          fontWeight: FontWeight.w600,
          height: 1,
          leadingDistribution: TextLeadingDistribution.even,
          color: foreground,
        ),
      ),
    );
  }
}
