import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'app_text_field.dart';

/// 单行文本输入弹窗，外观与 [showAppConfirmDialog] 同一套。
///
/// 返回去掉首尾空格后的文本；取消返回 null。输入为空时：[allowEmpty] 为 true
/// 返回空串（用于清空），否则也返回 null。
Future<String?> showAppInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  String confirmLabel = '确定',
  bool allowEmpty = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _InputDialog(
      title: title,
      initial: initial,
      hint: hint,
      confirmLabel: confirmLabel,
      allowEmpty: allowEmpty,
    ),
  );
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.initial,
    required this.hint,
    required this.confirmLabel,
    required this.allowEmpty,
  });

  final String title;
  final String initial;
  final String? hint;
  final String confirmLabel;
  final bool allowEmpty;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.pop(context, value.isEmpty && !widget.allowEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Dialog(
      elevation: 0,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: context.radii.sheetAll),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _controller,
              hint: widget.hint,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.muted,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: _submit,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      widget.confirmLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
