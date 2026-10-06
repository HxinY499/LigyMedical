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

  /// 紧凑档：列表行里的类型标签用。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (tone) {
      StatusTone.primary => (colors.primarySoft, colors.primary),
      StatusTone.danger => (colors.dangerSoft, colors.danger),
      StatusTone.accent => (
        colors.accent.withValues(alpha: colors.isDark ? 0.2 : 0.14),
        colors.accent,
      ),
      StatusTone.neutral => (colors.fill, colors.muted),
    };
    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: dense ? 11 : 12.5,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: foreground,
        ),
      ),
    );
  }
}
