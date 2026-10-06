import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/media/image_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_pill.dart';

/// 记录类型小标签：就诊走品牌色，体检走强调色。
class RecordKindTag extends StatelessWidget {
  const RecordKindTag({super.key, required this.kind});

  final RecordKind kind;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: kind.label,
      tone: kind == RecordKind.visit ? StatusTone.primary : StatusTone.accent,
      dense: true,
    );
  }
}

/// 同步解析本地缩略图；support 目录未预热时退回空白底。
class LocalThumbnail extends StatelessWidget {
  const LocalThumbnail({
    super.key,
    required this.relativePath,
    this.size = 64,
    this.cacheWidth = 240,
  });

  final String relativePath;
  final double size;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final path = ImageStorage.resolveSyncPath(relativePath);
    final placeholder = ColoredBox(color: colors.fill);
    return ClipRRect(
      borderRadius: context.radii.blockAll,
      child: SizedBox.square(
        dimension: size,
        child: path == null
            ? placeholder
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
