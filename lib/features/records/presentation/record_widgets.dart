import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/media/image_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/editable_photo_grid.dart';
import '../../../shared/widgets/photo_viewer.dart';
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

/// 列表缩略图的 provider。全屏查看器拿同一个 provider 垫底，才能命中已解码的缓存。
/// support 目录未预热时返回 null。
ImageProvider? localThumbnailProvider(String relativePath, int cacheWidth) {
  final path = ImageStorage.resolveSyncPath(relativePath);
  if (path == null) return null;
  return ResizeImage.resizeIfNeeded(cacheWidth, null, FileImage(File(path)));
}

/// 本地原图的 provider，全屏查看用。
ImageProvider localOriginalProvider(String relativePath) =>
    FileImage(File(ImageStorage.resolveSyncPath(relativePath) ?? ''));

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
    final provider = localThumbnailProvider(relativePath, cacheWidth);
    final placeholder = ColoredBox(color: colors.fill);
    return ClipRRect(
      borderRadius: context.radii.blockAll,
      child: SizedBox.square(
        dimension: size,
        child: provider == null
            ? placeholder
            : Image(
                image: provider,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

/// 编辑页缩略图边长与解码宽度。
const _kEditThumbSize = 76.0;
const _kEditThumbCacheWidth = 240;

/// 已落盘的照片：缩略图读小图，全屏读原图。给了 [onRename] 才显示名称行。
EditablePhoto storedEditablePhoto({
  required String path,
  required String thumbnailPath,
  required VoidCallback onRemove,
  String? name,
  VoidCallback? onRename,
}) {
  return EditablePhoto(
    photo: ViewerPhoto(
      image: localOriginalProvider(path),
      preview: localThumbnailProvider(thumbnailPath, _kEditThumbCacheWidth),
      caption: name,
    ),
    onRename: onRename,
    thumbnail: LocalThumbnail(
      relativePath: thumbnailPath,
      size: _kEditThumbSize,
      cacheWidth: _kEditThumbCacheWidth,
    ),
    onRemove: onRemove,
  );
}

/// 刚选上、还没保存的照片，直接读相册 / 相机给的文件。
EditablePhoto pendingEditablePhoto(
  BuildContext context, {
  required String sourcePath,
  required VoidCallback onRemove,
  String? name,
  VoidCallback? onRename,
}) {
  final original = FileImage(File(sourcePath));
  final preview = ResizeImage(original, width: _kEditThumbCacheWidth);
  return EditablePhoto(
    photo: ViewerPhoto(image: original, preview: preview, caption: name),
    onRename: onRename,
    thumbnail: ClipRRect(
      borderRadius: context.radii.blockAll,
      child: Image(
        image: preview,
        width: _kEditThumbSize,
        height: _kEditThumbSize,
        fit: BoxFit.cover,
      ),
    ),
    onRemove: onRemove,
  );
}
