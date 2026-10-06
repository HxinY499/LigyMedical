import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../core/theme/app_theme.dart';

/// 居中悬浮的主按钮，与 LigyTally「记一笔」同一套样式。
class AppFab extends StatelessWidget {
  const AppFab({super.key, required this.onPressed, this.tooltip});

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: colors.primary,
      // 深色下品牌色被提亮，白字对比不够；canvasBase 而不是 canvas，
      // 这是压在主色圆按钮上的前景色。
      foregroundColor: colors.isDark ? colors.canvasBase : Colors.white,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      shape: const CircleBorder(),
      child: const Icon(FLucideIcons.plus, size: 26),
    );
  }
}
