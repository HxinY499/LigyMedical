import '../../../core/database/app_database.dart';
import '../../../core/utils/format.dart';

enum RangeStatus { normal, low, high, unknown }

/// 数值相对参考范围的位置。没设参考范围时为 [RangeStatus.unknown]。
RangeStatus rangeStatus(IndicatorEntry indicator, double value) {
  final low = indicator.refLow;
  final high = indicator.refHigh;
  if (low == null && high == null) return RangeStatus.unknown;
  if (low != null && value < low) return RangeStatus.low;
  if (high != null && value > high) return RangeStatus.high;
  return RangeStatus.normal;
}

bool isAbnormal(IndicatorEntry indicator, double value) {
  final status = rangeStatus(indicator, value);
  return status == RangeStatus.low || status == RangeStatus.high;
}

/// `0 – 20`、`≤ 20`、`≥ 3`；没设返回 null。
String? formatRange(IndicatorEntry indicator) {
  final low = indicator.refLow;
  final high = indicator.refHigh;
  if (low != null && high != null) {
    return '${formatNumber(low)} – ${formatNumber(high)}';
  }
  if (high != null) return '≤ ${formatNumber(high)}';
  if (low != null) return '≥ ${formatNumber(low)}';
  return null;
}

/// `1.75 mg/L`
String formatValueWithUnit(double value, String unit) =>
    unit.isEmpty ? formatNumber(value) : '${formatNumber(value)} $unit';
