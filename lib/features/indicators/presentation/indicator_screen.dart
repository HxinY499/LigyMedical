import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../records/presentation/record_detail_screen.dart';
import '../application/indicator_range.dart';
import 'indicator_chart.dart';
import 'indicator_edit_screen.dart';
import 'indicators_tab.dart';

/// 单个指标：最新值 + 趋势图 + 全部历史。
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
      MaterialPageRoute<void>(
        builder: (_) => RecordDetailScreen(recordId: recordId),
      ),
    );
  }

  Future<void> _edit(BuildContext context, IndicatorEntry indicator) async {
    final resultId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => IndicatorEditScreen(indicator: indicator),
      ),
    );
    // 合并到了另一个指标：本页跟着换成那个指标。
    if (resultId != null && resultId != indicatorId && context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              IndicatorScreen(profileId: profileId, indicatorId: resultId),
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
                  title: '这个指标已经没有数据了',
                ),
              ),
          ],
        ),
      );
    }
    final indicator = series.indicator;
    final points = series.points;
    final latest = points.last;
    final previous = points.length > 1 ? points[points.length - 2] : null;
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
            padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + bottom),
            sliver: SliverList.list(
              children: [
                SurfaceCard(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Column(
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
                              fontWeight: FontWeight.w800,
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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (previous != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: DeltaText(
                                delta: latest.value - previous.value,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        range == null ? '未设置参考范围' : '参考范围 $range',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: colors.inactive,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: IndicatorChart(
                          series: series,
                          onTapPoint: (point) =>
                              _openRecord(context, point.recordId),
                        ),
                      ),
                    ],
                  ),
                ),
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
                          onTap: () => _openRecord(context, points[i].recordId),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.indicator,
    required this.point,
    required this.previous,
    required this.onTap,
  });

  final IndicatorEntry indicator;
  final IndicatorPoint point;
  final IndicatorPoint? previous;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final abnormal = isAbnormal(indicator, point.value);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                formatDotDate(point.date),
                style: TextStyle(fontSize: 14.5, color: colors.ink),
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
            const SizedBox(width: 6),
            Icon(FLucideIcons.chevronRight, size: 16, color: colors.faint),
          ],
        ),
      ),
    );
  }
}
