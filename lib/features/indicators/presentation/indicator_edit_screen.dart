import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/app_widgets.dart';

/// 新建 / 编辑指标：名称、单位、参考范围。
///
/// 编辑时改成本档案里已有的另一个名字会合并：ESR 和血沉记成了两个指标，
/// 把 ESR 改名为「血沉」，两边的数据就归到同一条趋势线上。
///
/// 返回最终指标的 id（新建的、或合并时的目标指标），取消返回 null。
class IndicatorEditScreen extends ConsumerStatefulWidget {
  const IndicatorEditScreen({
    super.key,
    required this.profileId,
    this.indicator,
  });

  final String profileId;

  /// null 表示新建。
  final IndicatorEntry? indicator;

  @override
  ConsumerState<IndicatorEditScreen> createState() =>
      _IndicatorEditScreenState();
}

class _IndicatorEditScreenState extends ConsumerState<IndicatorEditScreen> {
  late final _name = TextEditingController(text: widget.indicator?.name);
  late final _unit = TextEditingController(text: widget.indicator?.unit);
  late final _low = TextEditingController(
    text: widget.indicator?.refLow == null
        ? ''
        : formatNumber(widget.indicator!.refLow!),
  );
  late final _high = TextEditingController(
    text: widget.indicator?.refHigh == null
        ? ''
        : formatNumber(widget.indicator!.refHigh!),
  );
  bool _saving = false;

  bool get _editing => widget.indicator != null;

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _low.dispose();
    _high.dispose();
    super.dispose();
  }

  void _error(String message) {
    showAppToast(context, message: message, level: AppToastLevel.error);
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final name = _name.text.trim();
    if (name.isEmpty) return _error('请填写名称');
    final lowText = _low.text.trim();
    final highText = _high.text.trim();
    final low = parseNumber(lowText);
    final high = parseNumber(highText);
    if ((lowText.isNotEmpty && low == null) ||
        (highText.isNotEmpty && high == null)) {
      return _error('参考范围要填数字');
    }
    if (low != null && high != null && low > high) {
      return _error('下限不能大于上限');
    }

    final indicator = widget.indicator;
    if (indicator == null) {
      setState(() => _saving = true);
      final id = await db.createIndicator(
        id: const Uuid().v4(),
        profileId: widget.profileId,
        name: name,
        unit: _unit.text.trim(),
        refLow: low,
        refHigh: high,
      );
      if (!mounted) return;
      if (id == null) {
        setState(() => _saving = false);
        return _error('已有指标「$name」');
      }
      Navigator.of(context).pop(id);
      return;
    }

    final others = await db.indicatorList(indicator.profileId);
    final target = others
        .where((item) => item.name == name && item.id != indicator.id)
        .firstOrNull;
    if (target != null) {
      if (!mounted) return;
      final confirmed = await showAppConfirmDialog(
        context,
        message: '已有指标「$name」\n合并后这里的数据会并入「$name」，单位和参考范围以「$name」为准。',
        confirmLabel: '合并',
        accent: context.colors.primary,
      );
      if (!confirmed) return;
    }

    setState(() => _saving = true);
    final resultId = await db.renameIndicator(indicator.id, name);
    if (target == null) {
      await db.updateIndicator(
        id: resultId,
        unit: _unit.text.trim(),
        refLow: low,
        refHigh: high,
      );
    }
    if (mounted) Navigator.of(context).pop(resultId);
  }

  Future<void> _delete() async {
    final indicator = widget.indicator!;
    final confirmed = await showAppConfirmDialog(
      context,
      message: '删除指标「${indicator.name}」？\n它的全部数值都会删除，包括记录里填写的。',
      confirmLabel: '删除',
    );
    if (!confirmed || !mounted) return;
    await ref.read(databaseProvider).deleteIndicator(indicator.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    const numberKeyboard = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );
    return Scaffold(
      body: AppTopBar(
        title: _editing ? '编辑指标' : '新建指标',
        actions: [
          if (_editing)
            AppHeaderAction(
              icon: FLucideIcons.trash2,
              tooltip: '删除指标',
              onTap: _delete,
            ),
        ],
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottom),
            sliver: SliverList.list(
              children: [
                AppTextField(
                  controller: _name,
                  label: const Text('名称'),
                  autofocus: !_editing,
                ),
                if (_editing) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '改成已有指标的名字会把两者合并',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.inactive,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                AppTextField(controller: _unit, label: const Text('单位')),
                const SizedBox(height: 16),
                const FormSectionLabel('参考范围（可只填一边）'),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _low,
                        hint: '下限',
                        keyboardType: numberKeyboard,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('–'),
                    ),
                    Expanded(
                      child: AppTextField(
                        controller: _high,
                        hint: '上限',
                        keyboardType: numberKeyboard,
                      ),
                    ),
                  ],
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
