import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/ledger_date.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../indicators/application/indicator_range.dart';
import 'record_detail_screen.dart';
import 'record_widgets.dart';
import '../../profiles/presentation/profile_theme.dart';

/// 档案的记录时间线：按月分组，每月一张卡，月内记录用发丝线分隔。
class RecordsTab extends ConsumerStatefulWidget {
  const RecordsTab({super.key, required this.profileId});

  final String profileId;

  @override
  ConsumerState<RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends ConsumerState<RecordsTab> {
  static const _all = '全部';

  String _filter = _all;

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(recordsProvider(widget.profileId));
    return records.when(
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
            child: EmptyState(icon: FLucideIcons.notebookPen, title: '还没有记录'),
          );
        }
        final filtered = _filter == _all
            ? items
            : items
                  .where((item) => item.record.recordKind.label == _filter)
                  .toList();
        final groups = <String, List<RecordBundle>>{};
        for (final item in filtered) {
          groups
              .putIfAbsent(item.record.date.substring(0, 7), () => [])
              .add(item);
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.list(
            children: [
              ChoiceChips(
                labels: [
                  _all,
                  for (final kind in RecordKind.values) kind.label,
                ],
                selected: _filter,
                onTap: (value) => setState(() => _filter = value),
              ),
              if (filtered.isEmpty)
                const EmptyState(icon: FLucideIcons.searchX, title: '没有这类记录'),
              for (final entry in groups.entries) ...[
                _MonthHeader(month: entry.key),
                _MonthCard(items: entry.value),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month});

  /// `yyyy-MM`
  final String month;

  @override
  Widget build(BuildContext context) {
    final year = int.parse(month.substring(0, 4));
    final monthNumber = int.parse(month.substring(5, 7));
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        '$year年$monthNumber月',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.colors.muted,
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.items});

  final List<RecordBundle> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 68,
                color: colors.lineSoft,
              ),
            RecordRow(bundle: items[i]),
          ],
        ],
      ),
    );
  }
}

/// 时间线上的一条记录：日期栏 + 标题 / 内容 / 指标，有图时右侧挂缩略图。
class RecordRow extends StatelessWidget {
  const RecordRow({super.key, required this.bundle});

  final RecordBundle bundle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final record = bundle.record;
    final date = dateFromKey(record.date);
    final images = bundle.attachments
        .where((a) => a.kind == AttachmentKind.image.index)
        .toList();
    final firstThumb = images.isEmpty ? null : images.first.thumbnailPath;
    final title = record.hospital.isNotEmpty
        ? record.hospital
        : record.recordKind.label;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        profileRoute<void>(
          record.profileId,
          (_) => RecordDetailScreen(recordId: record.id),
        ),
      ),
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
                    formatWeekday(date),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            color: colors.ink,
                          ),
                        ),
                      ),
                      // 就诊是默认类型，每条都标一遍只是噪音；只标出体检。
                      if (record.recordKind == RecordKind.checkup) ...[
                        const SizedBox(width: 6),
                        RecordKindTag(kind: record.recordKind),
                      ],
                    ],
                  ),
                  if (record.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        record.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.5,
                          color: colors.muted,
                        ),
                      ),
                    ),
                  if (bundle.indicators.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _IndicatorLine(items: bundle.indicators),
                    ),
                ],
              ),
            ),
            if (firstThumb != null) ...[
              const SizedBox(width: 12),
              LocalThumbnail(relativePath: firstThumb, size: 48),
            ] else if (bundle.attachments.isNotEmpty) ...[
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  FLucideIcons.paperclip,
                  size: 15,
                  color: colors.inactive,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 行内指标：`血沉 2 mm/h   C反应蛋白 1.75 mg/L ↑`，异常值标红。
class _IndicatorLine extends StatelessWidget {
  const _IndicatorLine({required this.items});

  final List<RecordIndicator> items;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const TextSpan(text: '    '),
            TextSpan(
              text: '${items[i].indicator.name} ',
              style: TextStyle(color: colors.inactive),
            ),
            TextSpan(
              text: _valueText(items[i]),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isAbnormal(items[i].indicator, items[i].value.value)
                    ? colors.danger
                    : colors.ink,
              ),
            ),
          ],
        ],
      ),
      style: const TextStyle(fontSize: 12.5, height: 1.5),
    );
  }

  static String _valueText(RecordIndicator item) {
    final arrow = switch (rangeStatus(item.indicator, item.value.value)) {
      RangeStatus.high => ' ↑',
      RangeStatus.low => ' ↓',
      _ => '',
    };
    return formatValueWithUnit(item.value.value, item.indicator.unit) + arrow;
  }
}
