import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ledger_date.dart';
import '../../../shared/widgets/app_widgets.dart';

/// 在指标页单独添加 / 修改一次数值（不属于任何记录）。
class IndicatorValueEditorScreen extends ConsumerStatefulWidget {
  const IndicatorValueEditorScreen({
    super.key,
    required this.indicator,
    this.point,
  });

  final IndicatorEntry indicator;

  /// null 表示新建。只会传入单独添加的数值，来自记录的在记录里改。
  final IndicatorPoint? point;

  @override
  ConsumerState<IndicatorValueEditorScreen> createState() =>
      _IndicatorValueEditorScreenState();
}

class _IndicatorValueEditorScreenState
    extends ConsumerState<IndicatorValueEditorScreen> {
  late DateTime _date = widget.point == null
      ? dateOnly(DateTime.now())
      : dateFromKey(widget.point!.date);
  late final _value = TextEditingController(
    text: widget.point == null ? '' : formatNumber(widget.point!.value),
  );
  bool _saving = false;

  bool get _editing => widget.point != null;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = parseNumber(_value.text);
    if (value == null) {
      showAppToast(context, message: '请填写数字', level: AppToastLevel.error);
      return;
    }
    setState(() => _saving = true);
    await ref
        .read(databaseProvider)
        .saveStandaloneValue(
          id: widget.point?.valueId ?? const Uuid().v4(),
          indicatorId: widget.indicator.id,
          date: dateKey(_date),
          value: value,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showAppConfirmDialog(
      context,
      message: '删除这次数值？',
      confirmLabel: '删除',
    );
    if (!confirmed || !mounted) return;
    await ref
        .read(databaseProvider)
        .deleteIndicatorValue(widget.point!.valueId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.indicator.unit;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: AppTopBar(
        title: widget.indicator.name,
        actions: [
          if (_editing)
            AppHeaderAction(
              icon: FLucideIcons.trash2,
              tooltip: '删除',
              onTap: _delete,
            ),
        ],
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
            sliver: SliverList.list(
              children: [
                DateField(
                  value: _date,
                  onChanged: (value) => setState(() => _date = value),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _value,
                  label: Text(unit.isEmpty ? '数值' : '数值（$unit）'),
                  autofocus: !_editing,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                ),
                const SizedBox(height: 28),
                BottomActionButton(
                  label: '保存',
                  busy: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
