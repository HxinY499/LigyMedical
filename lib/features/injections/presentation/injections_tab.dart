import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ledger_date.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/settings_widgets.dart';
import '../application/injection_schedule.dart';
import 'injection_calendar.dart';
import 'injection_editor_screen.dart';

enum _View { list, calendar }

class InjectionsTab extends ConsumerStatefulWidget {
  const InjectionsTab({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<InjectionsTab> createState() => _InjectionsTabState();
}

class _InjectionsTabState extends ConsumerState<InjectionsTab> {
  _View _view = _View.list;

  void _openEditor({InjectionEntry? entry, DateTime? date}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InjectionEditorScreen(
          profileId: widget.profileId,
          entry: entry,
          initialDate: date,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final planAsync = ref.watch(injectionPlanProvider(widget.profileId));
    final injectionsAsync = ref.watch(injectionsProvider(widget.profileId));
    final injections = injectionsAsync.value;
    if (injections == null || planAsync.isLoading) {
      return const SliverToBoxAdapter();
    }
    final plan = planAsync.value;
    final interval = plan?.intervalDays ?? 14;
    final sites = plan?.siteList ?? splitSites(kDefaultInjectionSites);
    final next = nextInjectionDate(injections, interval);

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.list(
        children: [
          _SummaryCard(
            plan: plan,
            next: next,
            suggestedSite: suggestSite(sites, injections.firstOrNull?.site),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    injections.isEmpty ? '注射记录' : '已打 ${injections.length} 针',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.muted,
                    ),
                  ),
                ),
                SettingsToggleTrack(
                  children: [
                    SettingsToggleIcon(
                      icon: FLucideIcons.list,
                      tooltip: '列表',
                      selected: _view == _View.list,
                      onTap: () => setState(() => _view = _View.list),
                    ),
                    SettingsToggleIcon(
                      icon: FLucideIcons.calendarDays,
                      tooltip: '日历',
                      selected: _view == _View.calendar,
                      onTap: () => setState(() => _view = _View.calendar),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_view == _View.calendar)
            InjectionCalendar(
              injections: injections,
              sites: sites,
              intervalDays: interval,
              onTapInjection: (entry) => _openEditor(entry: entry),
              onTapEmptyDay: (date) => _openEditor(date: date),
            )
          else if (injections.isEmpty)
            const EmptyState(icon: FLucideIcons.syringe, title: '还没有注射记录')
          else
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < injections.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 68,
                        color: colors.lineSoft,
                      ),
                    _InjectionRow(
                      entry: injections[i],
                      number: injections.length - i,
                      intervalDays: intervalBefore(injections, i),
                      planInterval: interval,
                      onTap: () => _openEditor(entry: injections[i]),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 下次注射概要：全部左对齐，只有大日期一个视觉重点。
///
/// 记录注射走页面右下角的 + 号，计划设置走页头图标，卡里不再放按钮。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.plan,
    required this.next,
    required this.suggestedSite,
  });

  final InjectionPlanEntry? plan;
  final DateTime? next;
  final String? suggestedSite;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final next = this.next;
    final overdue = next != null && next.isBefore(dateOnly(DateTime.now()));
    final drug = plan?.drug ?? '';
    final note = plan?.note ?? '';
    final details = [
      if (suggestedSite != null) '建议$suggestedSite',
      '每${plan?.intervalDays ?? 14}天',
    ].join(' · ');
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            drug.isEmpty ? '下次注射' : '下次注射 · $drug',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.muted),
          ),
          const SizedBox(height: 6),
          if (next == null)
            Text(
              '记录第一针后开始计算',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${next.month}月${next.day}日',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: overdue ? colors.danger : colors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatWeekday(next),
                  style: TextStyle(fontSize: 15, color: colors.muted),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: [
                if (next != null)
                  TextSpan(
                    text: '${formatRelativeDays(next)} · ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: overdue ? colors.danger : colors.primary,
                    ),
                  ),
                TextSpan(text: details),
              ],
            ),
            style: TextStyle(fontSize: 13.5, color: colors.muted),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 1, color: colors.lineSoft),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    FLucideIcons.info,
                    size: 14,
                    color: colors.accent,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: colors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 一针：与记录列表同一套行版式——左侧日期栏，中间部位 / 地点，右侧序号与间隔。
class _InjectionRow extends StatelessWidget {
  const _InjectionRow({
    required this.entry,
    required this.number,
    required this.intervalDays,
    required this.planInterval,
    required this.onTap,
  });

  final InjectionEntry entry;
  final int number;
  final int? intervalDays;
  final int planInterval;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final date = dateFromKey(entry.date);
    final interval = intervalDays;
    final late = interval != null && interval > planInterval;
    final title = [
      if (entry.site.isNotEmpty) entry.site,
      if (entry.place.isNotEmpty) entry.place,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: colors.ink,
                    ),
                  ),
                  Text(
                    '${date.month}月',
                    style: TextStyle(fontSize: 11, color: colors.inactive),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty
                        ? (entry.drug.isEmpty ? '注射' : entry.drug)
                        : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: colors.ink,
                    ),
                  ),
                  if (title.isNotEmpty && entry.drug.isNotEmpty)
                    Text(
                      entry.drug,
                      style: TextStyle(fontSize: 13, color: colors.muted),
                    ),
                  if (entry.note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        entry.note,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: colors.muted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '第$number针',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: colors.inactive,
                  ),
                ),
                if (interval != null)
                  Text(
                    '间隔$interval天',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: late ? FontWeight.w600 : FontWeight.w400,
                      color: late ? colors.accent : colors.inactive,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
