import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ledger_date.dart';
import '../application/indicator_range.dart';

/// 指标趋势折线图。
///
/// 横轴按**真实日期间隔**排布而不是等距：复查间隔从一个月到四个月不等，
/// 等距排列会把趋势的快慢画歪。参考范围画成一条浅色带，超出范围的点标红。
class IndicatorChart extends StatelessWidget {
  const IndicatorChart({super.key, required this.series, this.onTapPoint});

  final IndicatorSeries series;
  final ValueChanged<IndicatorPoint>? onTapPoint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final indicator = series.indicator;
    final points = series.points;
    final origin = dateFromKey(points.first.date);
    double xOf(IndicatorPoint point) =>
        dateFromKey(point.date).difference(origin).inDays.toDouble();

    final spots = [for (final point in points) FlSpot(xOf(point), point.value)];
    final lastX = spots.last.x;
    // 单点或同一天的多个点：给横轴撑出宽度，否则 minX == maxX 画不出来。
    final span = lastX == 0 ? 30.0 : lastX;
    final minX = lastX == 0 ? -15.0 : -span * 0.04;
    final maxX = lastX == 0 ? 15.0 : span * 1.04;

    final values = [
      ...points.map((p) => p.value),
      ?indicator.refLow,
      ?indicator.refHigh,
    ];
    var minY = values.reduce(math.min);
    var maxY = values.reduce(math.max);
    final pad = maxY == minY ? (maxY.abs() * 0.2 + 1) : (maxY - minY) * 0.18;
    minY -= pad;
    maxY += pad;
    // 全为非负的指标不让纵轴掉到负数。
    if (values.every((v) => v >= 0)) minY = math.max(0, minY);

    final low = indicator.refLow;
    final high = indicator.refHigh;
    final hasRange = low != null || high != null;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: _niceStep(maxY - minY),
          getDrawingHorizontalLine: (_) => FlLine(
            color: colors.lineSoft,
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: [
            if (hasRange)
              HorizontalRangeAnnotation(
                y1: low ?? minY,
                y2: high ?? maxY,
                color: colors.success.withValues(alpha: 0.09),
              ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: _niceStep(maxY - minY),
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (value, meta) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  formatNumber(double.parse(value.toStringAsFixed(2))),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 10.5, color: colors.inactive),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                // 只在数据点上标日期，点太密时抽稀，从最新一点倒着数。
                final index = spots.indexWhere((s) => s.x == value);
                if (index < 0) return const SizedBox.shrink();
                final every = (spots.length / 5).ceil();
                if ((spots.length - 1 - index) % every != 0) {
                  return const SizedBox.shrink();
                }
                final date = dateFromKey(points[index].date);
                final sameYear =
                    dateFromKey(points.first.date).year ==
                    dateFromKey(points.last.date).year;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    sameYear
                        ? '${date.month}/${date.day}'
                        : '${date.year % 100}/${date.month}',
                    style: TextStyle(fontSize: 10.5, color: colors.inactive),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchSpotThreshold: 24,
          touchCallback: (event, response) {
            if (event is! FlTapUpEvent) return;
            final spot = response?.lineBarSpots?.firstOrNull;
            if (spot == null) return;
            onTapPoint?.call(points[spot.spotIndex]);
          },
          getTouchedSpotIndicator: (barData, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(
                  color: colors.primary,
                  strokeWidth: 1.2,
                  dashArray: const [3, 3],
                ),
                FlDotData(
                  getDotPainter: (spot, percent, bar, index) =>
                      FlDotCirclePainter(
                        radius: 5,
                        color: colors.surface,
                        strokeWidth: 3,
                        strokeColor: colors.primary,
                      ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.ink,
            tooltipBorderRadius: context.radii.chipAll,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  formatValueWithUnit(spot.y, indicator.unit),
                  TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors.canvasBase,
                  ),
                  children: [
                    TextSpan(
                      text: '\n${formatDotDate(points[spot.spotIndex].date)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: colors.canvasBase.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: colors.primary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            dotData: FlDotData(
              getDotPainter: (spot, percent, bar, index) {
                final abnormal = isAbnormal(indicator, spot.y);
                return FlDotCirclePainter(
                  radius: 4,
                  color: abnormal ? colors.danger : colors.surface,
                  strokeWidth: 2.5,
                  strokeColor: abnormal ? colors.danger : colors.primary,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colors.primary.withValues(alpha: 0.16),
                  colors.primary.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 把纵轴范围切成约 4 格的「好看」步长（1/2/5 × 10^n）。
  static double _niceStep(double range) {
    if (range <= 0) return 1;
    final raw = range / 4;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
    final residual = raw / magnitude;
    final nice = residual < 1.5
        ? 1
        : residual < 3
        ? 2
        : residual < 7
        ? 5
        : 10;
    return nice * magnitude.toDouble();
  }
}

/// 列表里的迷你走势线。
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(64, 26),
      painter: _SparklinePainter(values, color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minV = values.reduce(math.min);
    final maxV = values.reduce(math.max);
    final range = maxV - minV;
    Offset at(int i) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y = range == 0
          ? size.height / 2
          : size.height - (values[i] - minV) / range * (size.height - 4) - 2;
      return Offset(x, y);
    }

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (values.length > 1) {
      final path = Path()..moveTo(at(0).dx, at(0).dy);
      for (var i = 1; i < values.length; i++) {
        path.lineTo(at(i).dx, at(i).dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(at(values.length - 1), 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.values != values;
}
