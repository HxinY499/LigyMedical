import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/option_sheet.dart';
import '../../profiles/presentation/profile_theme.dart';
import '../../records/presentation/record_detail_screen.dart';
import '../application/indicator_range.dart';
import 'indicator_chart.dart';
import 'indicator_edit_screen.dart';
import 'indicator_value_editor_screen.dart';
import 'indicators_tab.dart';

enum _ValueAction { edit, delete }

/// 单个指标：最新值 + 趋势图 + 全部历史。
///
/// 数值有两种来源：记录里填的（点开跳到那条记录），和在这里单独添加的
/// （点了不跳转，长按编辑或删除）。
class IndicatorScreen extends ConsumerWidget {
  const IndicatorScreen({
    super.key,
    required this.profileId,
    required this.indicatorId,
  });

  final String profileId;
  final String indicatorId;

  void _openRecord(BuildContext context, String recordId) {
    Navigator.of(context).push(
      profileRoute<void>(
        profileId,
        (_) => RecordDetailScreen(recordId: recordId),
      ),
    );
  }

  void _openValueEditor(
    BuildContext context,
    IndicatorEntry indicator, [
    IndicatorPoint? point,
  ]) {
    Navigator.of(context).push(
      profileRoute<void>(
        profileId,
        (_) => IndicatorValueEditorScreen(indicator: indicator, point: point),
      ),
    );
  }

  Future<void> _onLongPressValue(
    BuildContext context,
    WidgetRef ref,
    IndicatorEntry indicator,
    IndicatorPoint point,
  ) async {
    final action = await showOptionSheet<_ValueAction?>(
      context,
      title:
          '${formatDotDate(point.date)} · '
          '${formatValueWithUnit(point.value, indicator.unit)}',
      current: null,
      options: const [
        SheetOption(
          value: _ValueAction.edit,
          label: '编辑',
          icon: FLucideIcons.pencil,
        ),
        SheetOption(
          value: _ValueAction.delete,
          label: '删除',
          icon: FLucideIcons.trash2,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case _ValueAction.edit:
        _openValueEditor(context, indicator, point);
      case _ValueAction.delete:
        final confirmed = await showAppConfirmDialog(
          context,
          message: '删除 ${formatDotDate(point.date)} 这次数值？',
          confirmLabel: '删除',
        );
        if (confirmed) {
          await ref.read(databaseProvider).deleteIndicatorValue(point.valueId);
        }
      case null:
        break;
    }
  }

  Future<void> _edit(BuildContext context, IndicatorEntry indicator) async {
    final resultId = await Navigator.of(context).push<String>(
      profileRoute<String>(
        profileId,
        (_) => IndicatorEditScreen(profileId: profileId, indicator: indicator),
      ),
    );
    // 合并到了另一个指标：本页跟着换成那个指标。
    if (resultId != null && resultId != indicatorId && context.mounted) {
      Navigator.of(context).pushReplacement(
        profileRoute<void>(
          profileId,
          (_) => IndicatorScreen(profileId: profileId, indicatorId: resultId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final async = ref.watch(
      oneSeriesProvider((profileId: profileId, indicatorId: indicatorId)),
    );
    final series = async.value;
    if (series == null) {
      return Scaffold(
        body: AppTopBar(
          title: '指标',
          slivers: [
            if (!async.isLoading)
              const SliverToBoxAdapter(
                child: EmptyState(
                  icon: FLucideIcons.chartLine,
                  title: '这个指标已经删除了',
                ),
              ),
          ],
        ),
      );
    }
    final indicator = series.indicator;
    final points = series.points;
    final range = formatRange(indicator);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: AppTopBar(
        title: indicator.name,
        actions: [
          AppHeaderAction(
            icon: FLucideIcons.pencil,
            tooltip: '编辑指标',
            onTap: () => _edit(context, indicator),
          ),
        ],
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 104 + bottom),
            sliver: SliverList.list(
              children: [
                SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: points.isEmpty
                      ? _EmptySummary(range: range)
                      : _Summary(
                          series: series,
                          range: range,
                          onTapPoint: (point) {
                            final recordId = point.recordId;
                            if (recordId != null) {
                              _openRecord(context, recordId);
                            }
                          },
                        ),
                ),
                if (points.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  FormSectionLabel('历史 · ${points.length} 次'),
                  SurfaceCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (var i = points.length - 1; i >= 0; i--) ...[
                          if (i < points.length - 1)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: colors.lineSoft,
                            ),
                          _HistoryRow(
                            indicator: indicator,
                            point: points[i],
                            previous: i > 0 ? points[i - 1] : null,
                            onTap: points[i].recordId == null
                                ? null
                                : () =>
                                      _openRecord(context, points[i].recordId!),
                            onLongPress: points[i].recordId == null
                                ? () => _onLongPressValue(
                                    context,
                                    ref,
                                    indicator,
                                    points[i],
                                  )
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AppFab(
        tooltip: '添加数值',
        onPressed: () => _openValueEditor(context, indicator),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.series,
    required this.range,
    required this.onTapPoint,
  });

  final IndicatorSeries series;
  final String? range;
  final ValueChanged<IndicatorPoint> onTapPoint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final indicator = series.indicator;
    final points = series.points;
    final latest = points.last;
    final previous = points.length > 1 ? points[points.length - 2] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近一次 · ${formatDotDate(latest.date)}',
          style: TextStyle(fontSize: 12.5, color: colors.muted),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatNumber(latest.value),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: isAbnormal(indicator, latest.value)
                    ? colors.danger
                    : colors.ink,
              ),
            ),
            if (indicator.unit.isNotEmpty) ...[
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  indicator.unit,
                  style: TextStyle(fontSize: 14, color: colors.muted),
                ),
              ),
            ],
            const Spacer(),
            if (previous != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: DeltaText(delta: latest.value - previous.value),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          range == null ? '未设置参考范围' : '参考范围 $range',
          style: TextStyle(fontSize: 12.5, color: colors.inactive),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: IndicatorChart(series: series, onTapPoint: onTapPoint),
        ),
      ],
    );
  }
}

class _EmptySummary extends StatelessWidget {
  const _EmptySummary({required this.range});

  final String? range;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '还没有数据',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            range == null ? '未设置参考范围' : '参考范围 $range',
            style: TextStyle(fontSize: 12.5, color: colors.inactive),
          ),
        ],
      ),
    );
  }
}

/// 历史里的一次数值。来自记录的带「来自记录」和箭头，点开跳到记录；
/// 单独添加的点了不跳转，长按编辑或删除。
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.indicator,
    required this.point,
    required this.previous,
    required this.onTap,
    required this.onLongPress,
  });

  final IndicatorEntry indicator;
  final IndicatorPoint point;
  final IndicatorPoint? previous;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final abnormal = isAbnormal(indicator, point.value);
    final fromRecord = point.recordId != null;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDotDate(point.date),
                    style: TextStyle(fontSize: 14.5, color: colors.ink),
                  ),
                  if (fromRecord)
                    Text(
                      '来自记录',
                      style: TextStyle(fontSize: 11.5, color: colors.inactive),
                    ),
                ],
              ),
            ),
            if (previous != null) ...[
              DeltaText(delta: point.value - previous!.value),
              const SizedBox(width: 14),
            ],
            Text(
              formatValueWithUnit(point.value, indicator.unit),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: abnormal ? colors.danger : colors.ink,
              ),
            ),
            SizedBox(
              width: 22,
              child: fromRecord
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        FLucideIcons.chevronRight,
                        size: 16,
                        color: colors.faint,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
