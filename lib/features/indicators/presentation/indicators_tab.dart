import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../application/indicator_range.dart';
import 'indicator_chart.dart';
import 'indicator_screen.dart';
import '../../profiles/presentation/profile_theme.dart';

/// 档案里所有填过数值的指标，最近测过的在前。
class IndicatorsTab extends ConsumerWidget {
  const IndicatorsTab({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final series = ref.watch(indicatorSeriesProvider(profileId));
    return series.when(
      loading: () => const SliverToBoxAdapter(),
      error: (error, _) => SliverToBoxAdapter(
        child: EmptyState(
          icon: FLucideIcons.circleAlert,
          title: '读取失败',
          detail: '$error',
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const SliverToBoxAdapter(
            child: EmptyState(icon: FLucideIcons.chartLine, title: '还没有指标'),
          );
        }
        final colors = context.colors;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 16,
                        color: colors.lineSoft,
                      ),
                    _SeriesRow(
                      series: items[i],
                      onTap: () => Navigator.of(context).push(
                        profileRoute<void>(
                          profileId,
                          (_) => IndicatorScreen(
                            profileId: profileId,
                            indicatorId: items[i].indicator.id,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.series, required this.onTap});

  final IndicatorSeries series;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final indicator = series.indicator;
    final points = series.points;
    if (points.isEmpty) {
      return _EmptySeriesRow(indicator: indicator, onTap: onTap);
    }
    final latest = points.last;
    final previous = points.length > 1 ? points[points.length - 2] : null;
    final abnormal = isAbnormal(indicator, latest.value);
    final delta = previous == null ? null : latest.value - previous.value;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    indicator.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${formatDotDate(latest.date)} · 共 ${points.length} 次',
                    style: TextStyle(fontSize: 12, color: colors.inactive),
                  ),
                ],
              ),
            ),
            Sparkline(
              values: [for (final p in points) p.value],
              color: abnormal ? colors.danger : colors.primary,
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 84,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formatNumber(latest.value),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: abnormal ? colors.danger : colors.ink,
                          ),
                        ),
                        if (indicator.unit.isNotEmpty)
                          TextSpan(
                            text: ' ${indicator.unit}',
                            style: TextStyle(fontSize: 11, color: colors.muted),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  if (delta != null) DeltaText(delta: delta),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 新建了但还没填过数值的指标。
class _EmptySeriesRow extends StatelessWidget {
  const _EmptySeriesRow({required this.indicator, required this.onTap});

  final IndicatorEntry indicator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    indicator.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: colors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '暂无数据',
                    style: TextStyle(fontSize: 12, color: colors.inactive),
                  ),
                ],
              ),
            ),
            Icon(FLucideIcons.chevronRight, size: 16, color: colors.faint),
          ],
        ),
      ),
    );
  }
}

/// 与上次相比的变化：`↑ 0.15` / `↓ 2` / `持平`。
///
/// 只表达方向，不染红绿：指标升高是好是坏因项而异，统一染色会误导。
class DeltaText extends StatelessWidget {
  const DeltaText({super.key, required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rounded = double.parse(delta.toStringAsFixed(4));
    final text = rounded == 0
        ? '持平'
        : '${rounded > 0 ? '↑' : '↓'} ${formatNumber(rounded.abs())}';
    return Text(text, style: TextStyle(fontSize: 12, color: colors.muted));
  }
}
