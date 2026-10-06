import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import 'app_button.dart';
import 'app_picker_sheet.dart';

/// 表单分区标题，右侧可挂一个操作。
class FormSectionLabel extends StatelessWidget {
  const FormSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.muted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// 分区标题右侧的文字按钮。
class FormLinkButton extends StatelessWidget {
  const FormLinkButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = FLucideIcons.plus,
  });

  final String label;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: context.radii.chipAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colors.primary),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 点开选日期的只读字段，外观与输入框同一档。
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = '日期',
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: colors.ink,
            ),
          ),
        ),
        Material(
          color: colors.surface,
          shape: context.radii.blockShape(side: BorderSide(color: colors.line)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              final picked = await showAppDatePicker(context, initial: value);
              if (picked != null) onChanged(picked);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(FLucideIcons.calendar, size: 17, color: colors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formatFullDate(value),
                      style: TextStyle(fontSize: 15, color: colors.ink),
                    ),
                  ),
                  Icon(
                    FLucideIcons.chevronDown,
                    size: 16,
                    color: colors.inactive,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 卡片里的「标签：值」一行。
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: colors.muted, height: 1.45),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(fontSize: 14.5, color: colors.ink, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// 页面底部的主按钮：撑满宽度。
class BottomActionButton extends StatelessWidget {
  const BottomActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        onPress: busy ? null : onPressed,
        child: Text(busy ? '保存中…' : label),
      ),
    );
  }
}
