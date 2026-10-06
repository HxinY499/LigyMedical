import 'ledger_date.dart';

/// `2026-04-26` → `2026.04.26`，与原来语雀里的写法一致。
String formatDotDate(String key) => key.replaceAll('-', '.');

/// `4月26日 周日`
String formatDayWithWeekday(DateTime value) =>
    '${value.month}月${value.day}日 ${formatWeekday(value)}';

/// `2026年4月26日 周日`
String formatFullDate(DateTime value) =>
    '${value.year}年${formatDayWithWeekday(value)}';

/// 去掉多余的小数位：`1.0` → `1`，`1.750` → `1.75`。
String formatNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  var text = value.toStringAsFixed(4);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
}

/// 相对今天的说法：`今天` / `明天` / `3 天后` / `已过 2 天`。
String formatRelativeDays(DateTime target, {DateTime? today}) {
  final base = dateOnly(today ?? DateTime.now());
  final days = dateOnly(target).difference(base).inDays;
  if (days == 0) return '今天';
  if (days == 1) return '明天';
  if (days > 1) return '$days 天后';
  return '已过 ${-days} 天';
}

/// 解析用户输入的数字，允许全角小数点和首尾空格。非法返回 null。
double? parseNumber(String raw) {
  final text = raw.trim().replaceAll('。', '.').replaceAll('．', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}
