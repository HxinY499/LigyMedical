import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

import '../../core/theme/app_theme.dart';

/// 单选浮层里的一个选项。
class SheetOption<T> {
  const SheetOption({
    required this.value,
    required this.label,
    this.caption,
    this.icon,
  });

  final T value;
  final String label;

  /// 选项名下面的一行小字。
  final String? caption;

  final IconData? icon;
}

/// 通用单选浮层：标题 + 一行说明 + 若干选项行。
///
/// 点一下即选中并关闭，没有「确定」：单选浮层里没有别的东西可改，
/// 再要一次确认纯属多一步。
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required String title,
  String? caption,
  required T current,
  required List<SheetOption<T>> options,
}) {
  return showFSheet<T>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: null,
    builder: (sheetContext) => _OptionSheet<T>(
      title: title,
      caption: caption,
      current: current,
      options: options,
    ),
  );
}

class _OptionSheet<T> extends StatelessWidget {
  const _OptionSheet({
    required this.title,
    required this.caption,
    required this.current,
    required this.options,
  });

  final String title;
  final String? caption;
  final T current;
  final List<SheetOption<T>> options;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final caption = this.caption;
    return Material(
      color: colors.surface,
      shape: context.radii.sheetTopShape,
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
            if (caption != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: colors.muted,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            for (final option in options)
              _OptionRow<T>(
                option: option,
                selected: option.value == current,
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context, option.value);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final SheetOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final caption = option.caption;
    final icon = option.icon;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colors.primarySoft : colors.fill,
                  borderRadius: context.radii.chipAll,
                ),
                child: Icon(
                  icon,
                  size: 17,
                  color: selected ? colors.primary : colors.inactive,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? colors.primary : colors.ink,
                      height: 1.25,
                    ),
                  ),
                  if (caption != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: colors.inactive,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(FLucideIcons.check, size: 18, color: colors.primary),
          ],
        ),
      ),
    );
  }
}
