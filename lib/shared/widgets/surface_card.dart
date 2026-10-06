import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// 内容卡片：扁平白面，靠与页面底色的反差分层，不用阴影。
///
/// 白底必须由 [Material] 提供：水波画在最近的 Material 上，用不透明的
/// Container 当底会把水波整块盖住，按下毫无反馈。
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: context.radii.cardShape(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        highlightColor: colors.pressed,
        splashColor: colors.ripple,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
