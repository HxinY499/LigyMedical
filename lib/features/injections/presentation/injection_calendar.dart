import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/chinese_calendar.dart';
import '../../../core/utils/ledger_date.dart';
import '../../../shared/widgets/surface_card.dart';
import '../../profiles/presentation/profile_avatar.dart';
import '../application/injection_schedule.dart';

/// 注射月历：打过针的日子按部位着色，预计注射日画空心圈。
///
/// 预计日从最近一次实际注射起每隔一个间隔往后排，翻到哪个月都有。
/// 格子下方是阴历 / 节日 / 节气，右上角标法定节假日的「休」「班」。
/// 点打过针的日子编辑那一针，点其他日子在那天补记一针。左右滑动翻月。
class InjectionCalendar extends StatefulWidget {
  const InjectionCalendar({
    super.key,
    required this.injections,
    required this.sites,
    required this.intervalDays,
    required this.onTapInjection,
    required this.onTapEmptyDay,
  });

  /// 按日期倒序。
  final List<InjectionEntry> injections;
  final List<String> sites;
  final int intervalDays;
  final ValueChanged<InjectionEntry> onTapInjection;
  final ValueChanged<DateTime> onTapEmptyDay;

  @override
  State<InjectionCalendar> createState() => _InjectionCalendarState();
}

class _InjectionCalendarState extends State<InjectionCalendar> {
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  static const _cellHeight = 54.0;

  late DateTime _month = _initialMonth();

  DateTime? get _last => widget.injections.isEmpty
      ? null
      : dateFromKey(widget.injections.first.date);

  /// 默认停在下一个预计日所在月：日历最常被打开来看「下一针是哪天」。
  DateTime _initialMonth() {
    final anchor =
        nextInjectionDate(widget.injections, widget.intervalDays) ??
        DateTime.now();
    return DateTime(anchor.year, anchor.month);
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  Color _siteColor(String site) {
    final index = widget.sites.indexOf(site);
    if (index < 0) return context.colors.muted;
    return kProfileColors[index % kProfileColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final byDay = <String, InjectionEntry>{};
    // 列表是倒序的，同一天多针时保留最新录入那针。
    for (final entry in widget.injections.reversed) {
      byDay[entry.date] = entry;
    }
    final first = DateTime(_month.year, _month.month);
    final dayCount = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - DateTime.monday;
    final rows = ((leading + dayCount) / 7).ceil();
    final today = dateOnly(DateTime.now());
    final monthPrefix = dateKey(first).substring(0, 7);
    final doneCount = widget.injections
        .where((entry) => entry.date.startsWith(monthPrefix))
        .length;
    final projectedCount = [
      for (var d = 1; d <= dayCount; d++)
        if (isProjectedInjectionDay(
          DateTime(_month.year, _month.month, d),
          _last,
          widget.intervalDays,
        ))
          d,
    ].length;
    final summary = [
      if (doneCount > 0) '已打 $doneCount 针',
      if (projectedCount > 0) '预计 $projectedCount 针',
    ].join(' · ');
    final usedSites = {
      for (final entry in widget.injections)
        if (entry.date.startsWith(monthPrefix) && entry.site.isNotEmpty)
          entry.site,
    };

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 200) return;
          _shift(velocity < 0 ? 1 : -1);
        },
        child: Column(
          children: [
            Row(
              children: [
                _ArrowButton(
                  icon: FLucideIcons.chevronLeft,
                  onTap: () => _shift(-1),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${_month.year}年${_month.month}月',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                        ),
                      ),
                      Text(
                        summary.isEmpty ? '本月无注射' : summary,
                        style: TextStyle(fontSize: 12, color: colors.inactive),
                      ),
                    ],
                  ),
                ),
                _ArrowButton(
                  icon: FLucideIcons.chevronRight,
                  onTap: () => _shift(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final label in _weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.inactive,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var row = 0; row < rows; row++)
              Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(
                      child: _buildCell(
                        row * 7 + column - leading + 1,
                        dayCount,
                        byDay,
                        today,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final site in widget.sites.where(usedSites.contains))
                  _Legend(color: _siteColor(site), label: site),
                if (projectedCount > 0)
                  _Legend(color: colors.primary, label: '预计', hollow: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(
    int dayNumber,
    int dayCount,
    Map<String, InjectionEntry> byDay,
    DateTime today,
  ) {
    if (dayNumber < 1 || dayNumber > dayCount) {
      return const SizedBox(height: _cellHeight);
    }
    final colors = context.colors;
    final day = DateTime(_month.year, _month.month, dayNumber);
    final entry = byDay[dateKey(day)];
    final projected =
        entry == null &&
        isProjectedInjectionDay(day, _last, widget.intervalDays);
    final overdue = projected && day.isBefore(today);
    final isToday = day == today;
    final siteColor = entry == null ? null : _siteColor(entry.site);
    final info = chineseDayInfo(day);
    final ringColor = overdue ? colors.danger : colors.primary;

    final Widget circle;
    if (siteColor != null) {
      circle = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: siteColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(
          '$dayNumber',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    } else {
      circle = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: projected ? Border.all(color: ringColor, width: 2) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '$dayNumber',
          style: TextStyle(
            fontSize: 13,
            fontWeight: isToday || projected
                ? FontWeight.w800
                : FontWeight.w500,
            color: projected
                ? ringColor
                : isToday
                ? colors.primary
                : colors.ink,
          ),
        ),
      );
    }

    final String caption;
    final Color captionColor;
    if (entry != null && entry.site.isNotEmpty) {
      caption = entry.site;
      captionColor = siteColor!;
    } else if (info.isFestival) {
      caption = info.label;
      captionColor = colors.danger;
    } else {
      caption = info.label;
      captionColor = colors.inactive;
    }

    return InkWell(
      onTap: () => entry == null
          ? widget.onTapEmptyDay(day)
          : widget.onTapInjection(entry),
      borderRadius: context.radii.chipAll,
      child: SizedBox(
        height: _cellHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  circle,
                  const SizedBox(height: 2),
                  Text(
                    caption,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 9.5,
                      height: 1.1,
                      color: captionColor,
                    ),
                  ),
                ],
              ),
            ),
            if (info.offDay != null)
              Positioned(
                top: 2,
                right: 4,
                child: Text(
                  info.offDay! ? '休' : '班',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: info.offDay! ? colors.success : colors.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkResponse(
      onTap: onTap,
      radius: 20,
      containedInkWell: true,
      customBorder: const CircleBorder(),
      highlightColor: colors.pressed,
      splashColor: colors.ripple,
      child: SizedBox.square(
        dimension: 40,
        child: Center(child: Icon(icon, size: 20, color: colors.ink)),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.hollow = false,
  });

  final Color color;
  final String label;
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: hollow ? null : color,
            shape: BoxShape.circle,
            border: hollow ? Border.all(color: color, width: 1.6) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.colors.muted),
        ),
      ],
    );
  }
}
