import '../../../core/database/app_database.dart';
import '../../../core/utils/ledger_date.dart';

/// 下次注射日期 = 最近一次实际注射 + 间隔。
///
/// 按实际日期顺延而不是按计划日期：延后打了一针，下一针也跟着往后挪。
/// [latestFirst] 须按日期倒序。没有任何记录时返回 null。
DateTime? nextInjectionDate(
  List<InjectionEntry> latestFirst,
  int intervalDays,
) {
  if (latestFirst.isEmpty) return null;
  return dateFromKey(latestFirst.first.date).add(Duration(days: intervalDays));
}

/// [day] 是否落在预计注射日上：最近一次实际注射之后，每隔 [intervalDays] 天一次，
/// 一直往后排。补记或改了最近一针，整条预测跟着重排。
bool isProjectedInjectionDay(
  DateTime day,
  DateTime? lastInjection,
  int intervalDays,
) {
  if (lastInjection == null || intervalDays < 1) return false;
  final days = dateOnly(day).difference(dateOnly(lastInjection)).inDays;
  return days > 0 && days % intervalDays == 0;
}

/// 按轮换顺序给出下一个部位：上次部位的下一个，循环。
///
/// 上次部位不在轮换表里（改过计划、或手填了别的）就从头开始。
String? suggestSite(List<String> sites, String? lastSite) {
  if (sites.isEmpty) return null;
  final index = lastSite == null ? -1 : sites.indexOf(lastSite);
  return sites[(index + 1) % sites.length];
}

/// 与上一针的间隔天数。[latestFirst] 须按日期倒序；最早那一针返回 null。
int? intervalBefore(List<InjectionEntry> latestFirst, int index) {
  if (index + 1 >= latestFirst.length) return null;
  return dateFromKey(
    latestFirst[index].date,
  ).difference(dateFromKey(latestFirst[index + 1].date)).inDays;
}
