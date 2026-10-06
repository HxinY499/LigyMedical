import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/database/app_database.dart';
import '../../../core/media/image_storage.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/ledger_date.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/photo_viewer.dart';
import '../../indicators/application/indicator_range.dart';
import '../../indicators/presentation/indicator_screen.dart';
import 'record_editor_screen.dart';
import 'record_widgets.dart';

class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RecordEntry r,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      message: '删除这条记录？\n附件和指标数据会一起删除，无法恢复。',
      confirmLabel: '删除',
    );
    if (!confirmed || !context.mounted) return;
    Navigator.of(context).pop();
    await ref.read(recordServiceProvider).delete(r);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundle = ref.watch(recordProvider(recordId)).value;
    final fieldDefs = ref.watch(fieldDefsProvider).value ?? const [];
    if (bundle == null) {
      return const Scaffold(
        body: AppTopBar(title: '记录', slivers: []),
      );
    }
    final record = bundle.record;
    final colors = context.colors;
    final images = bundle.attachments
        .where((a) => a.kind == AttachmentKind.image.index)
        .toList();
    final pdfs = bundle.attachments
        .where((a) => a.kind == AttachmentKind.pdf.index)
        .toList();
    final customFields = [
      for (final def in fieldDefs)
        if (bundle.fields[def.id] != null) (def.name, bundle.fields[def.id]!),
    ];
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: AppTopBar(
        title: record.recordKind.label,
        actions: [
          AppHeaderAction(
            icon: FLucideIcons.pencil,
            tooltip: '编辑',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RecordEditorScreen(
                  profileId: record.profileId,
                  bundle: bundle,
                ),
              ),
            ),
          ),
          AppHeaderAction(
            icon: FLucideIcons.trash2,
            tooltip: '删除',
            onTap: () => _delete(context, ref, record),
          ),
        ],
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + bottom),
            sliver: SliverList.list(
              children: [
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            formatFullDate(dateFromKey(record.date)),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: colors.ink,
                            ),
                          ),
                          RecordKindTag(kind: record.recordKind),
                        ],
                      ),
                      if (record.hospital.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              FLucideIcons.mapPin,
                              size: 14,
                              color: colors.muted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                record.hospital,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (record.content.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        SelectableText(
                          record.content,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: colors.ink,
                          ),
                        ),
                      ],
                      if (customFields.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Divider(height: 1, color: colors.lineSoft),
                        const SizedBox(height: 8),
                        for (final (name, value) in customFields)
                          InfoRow(label: name, value: value),
                      ],
                    ],
                  ),
                ),
                if (bundle.indicators.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const FormSectionLabel('指标'),
                  SurfaceCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (var i = 0; i < bundle.indicators.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: colors.lineSoft,
                            ),
                          _IndicatorRow(
                            item: bundle.indicators[i],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => IndicatorScreen(
                                  profileId: record.profileId,
                                  indicatorId:
                                      bundle.indicators[i].indicator.id,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  FormSectionLabel('图片 · ${images.length}'),
                  _ImageGrid(images: images),
                ],
                if (pdfs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  FormSectionLabel('PDF · ${pdfs.length}'),
                  for (final pdf in pdfs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PdfTile(
                        name: pdf.name,
                        sizeBytes: pdf.sizeBytes,
                        onTap: () => openStoredPdf(context, pdf.path),
                      ),
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

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({required this.item, required this.onTap});

  final RecordIndicator item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final status = rangeStatus(item.indicator, item.value.value);
    final abnormal = status == RangeStatus.high || status == RangeStatus.low;
    final range = formatRange(item.indicator);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.indicator.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                  if (range != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '参考 $range',
                        style: TextStyle(fontSize: 12, color: colors.inactive),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              formatValueWithUnit(item.value.value, item.indicator.unit),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: abnormal ? colors.danger : colors.ink,
              ),
            ),
            if (abnormal)
              Icon(
                status == RangeStatus.high
                    ? FLucideIcons.arrowUp
                    : FLucideIcons.arrowDown,
                size: 15,
                color: colors.danger,
              ),
            const SizedBox(width: 6),
            Icon(FLucideIcons.chartLine, size: 16, color: colors.faint),
          ],
        ),
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.images});

  final List<AttachmentEntry> images;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final size = (constraints.maxWidth - spacing * 2) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < images.length; i++)
              GestureDetector(
                onTap: () => showPhotoViewer(
                  context,
                  images: [
                    for (final image in images)
                      FileImage(
                        File(ImageStorage.resolveSyncPath(image.path) ?? ''),
                      ),
                  ],
                  initialIndex: i,
                ),
                child: LocalThumbnail(
                  relativePath: images[i].thumbnailPath ?? images[i].path,
                  size: size,
                  cacheWidth: 360,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// PDF 附件行。
class PdfTile extends StatelessWidget {
  const PdfTile({
    super.key,
    required this.name,
    required this.onTap,
    this.sizeBytes,
    this.onRemove,
  });

  final String name;
  final int? sizeBytes;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = sizeBytes;
    return Material(
      color: colors.surface,
      shape: context.radii.blockShape(side: BorderSide(color: colors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.dangerSoft,
                  borderRadius: context.radii.chipAll,
                ),
                alignment: Alignment.center,
                child: Icon(
                  FLucideIcons.fileText,
                  size: 18,
                  color: colors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? '报告.pdf' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.ink,
                      ),
                    ),
                    if (size != null)
                      Text(
                        _formatSize(size),
                        style: TextStyle(fontSize: 12, color: colors.inactive),
                      ),
                  ],
                ),
              ),
              if (onRemove != null)
                IconButton(
                  onPressed: onRemove,
                  icon: Icon(FLucideIcons.x, size: 18, color: colors.muted),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    FLucideIcons.externalLink,
                    size: 16,
                    color: colors.faint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

/// 用系统里的 PDF 阅读器打开已存附件。
Future<void> openStoredPdf(BuildContext context, String relativePath) async {
  final path = ImageStorage.resolveSyncPath(relativePath);
  if (path == null) return;
  final result = await OpenFilex.open(path, type: 'application/pdf');
  if (result.type != ResultType.done && context.mounted) {
    showAppToast(
      context,
      message: '无法打开 PDF',
      description: result.type == ResultType.noAppToOpen
          ? '手机上没有可以打开 PDF 的应用'
          : result.message,
      level: AppToastLevel.error,
    );
  }
}
