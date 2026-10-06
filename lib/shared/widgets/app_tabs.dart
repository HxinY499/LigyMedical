import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';

/// 一排等宽档位选一个：白色轨道 + 跟随滑动的品牌色浅底滑块，扁平无阴影。
///
/// 轨道用卡片面色而不是灰色填充：页面底本身就是浅灰，灰轨道压在上面
/// 几乎看不出边界。
class AppTabs<T> extends StatelessWidget {
  const AppTabs({
    super.key,
    required this.values,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
  });

  final List<T> values;
  final String Function(T value) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final duration = context.motion(const Duration(milliseconds: 180));
    final index = math.max(0, values.indexOf(selected));
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radii.blockAll,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slotWidth = constraints.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: slotWidth * index,
                top: 0,
                bottom: 0,
                width: slotWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primarySoft,
                    borderRadius: BorderRadius.circular(
                      math.max(0, context.radii.block - 4),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final value in values)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(value),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: duration,
                            // 在继承的样式上改，不是整个替换：替换会丢掉主题字体。
                            style: DefaultTextStyle.of(context).style.copyWith(
                              fontSize: 13.5,
                              fontWeight: value == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: value == selected
                                  ? colors.primary
                                  : colors.muted,
                            ),
                            child: Text(labelOf(value)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
