import 'package:lunar/lunar.dart';

/// 日历格子下方那行字 + 法定节假日标记。
class ChineseDayInfo {
  const ChineseDayInfo({
    required this.label,
    required this.isFestival,
    required this.offDay,
  });

  /// 节日 / 节气名，没有就是阴历日（初一显示月份，如「九月」）。
  final String label;

  /// [label] 是节日或节气（要醒目显示），而不是普通阴历日。
  final bool isFestival;

  /// true = 法定放假（休），false = 调休上班（班），null = 普通日子。
  ///
  /// 数据随 `lunar` 包发布，覆盖到包发布时国务院已公布的年份；
  /// 之后的年份为 null，等包更新。
  final bool? offDay;
}

final _cache = <int, ChineseDayInfo>{};

/// 公历节日只留国内日历常见的这几个；包里还有情人节、万圣节前夜等，
/// 挤在小格子里只会把阴历盖掉。
const _solarFestivals = {
  '元旦节',
  '妇女节',
  '劳动节',
  '青年节',
  '儿童节',
  '建党节',
  '建军节',
  '教师节',
  '国庆节',
};

ChineseDayInfo chineseDayInfo(DateTime day) {
  final key = day.year * 10000 + day.month * 100 + day.day;
  return _cache.putIfAbsent(key, () => _compute(day));
}

ChineseDayInfo _compute(DateTime day) {
  final solar = Solar.fromYmd(day.year, day.month, day.day);
  final lunar = solar.getLunar();
  final holiday = HolidayUtil.getHolidayByYmd(day.year, day.month, day.day);
  final offDay = holiday == null ? null : !holiday.isWork();

  // 传统节日优先于公历节日：同一天撞上时（如中秋撞国庆），中秋更有信息量。
  final festival = [
    ...lunar.getFestivals(),
    ...solar.getFestivals().where(_solarFestivals.contains),
    lunar.getJieQi(),
  ].where((name) => name.isNotEmpty).firstOrNull;
  if (festival != null) {
    return ChineseDayInfo(label: festival, isFestival: true, offDay: offDay);
  }
  final label = lunar.getDay() == 1
      ? '${lunar.getMonthInChinese()}月'
      : lunar.getDayInChinese();
  return ChineseDayInfo(label: label, isFestival: false, offDay: offDay);
}
