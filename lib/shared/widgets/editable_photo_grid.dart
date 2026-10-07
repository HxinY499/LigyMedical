import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import 'app_toast.dart';
import 'photo_viewer.dart';

/// 编辑页里的一张照片。
class EditablePhoto {
  const EditablePhoto({
    required this.photo,
    required this.thumbnail,
    required this.onRemove,
    this.onRename,
  });

  /// 点开后全屏查看的那张；名称取它的 [ViewerPhoto.caption]。
  final ViewerPhoto photo;
  final Widget thumbnail;
  final VoidCallback onRemove;

  /// 非 null 时缩略图下面有一行名称，点它改名。
  final VoidCallback? onRename;
}

/// 编辑页的照片格：点开全屏看原图（可左右翻），右上角 × 移除。
class EditablePhotoGrid extends StatelessWidget {
  const EditablePhotoGrid({
    super.key,
    required this.photos,
    this.thumbnailSize = 76,
  });

  final List<EditablePhoto> photos;

  /// 名称行与缩略图同宽。
  final double thumbnailSize;

  @override
  Widget build(BuildContext context) {
    final viewerPhotos = [for (final photo in photos) photo.photo];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (index, photo) in photos.indexed)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _removable(context, photo, viewerPhotos, index),
              if (photo.onRename case final onRename?)
                _NameButton(
                  name: photo.photo.caption ?? '',
                  width: thumbnailSize,
                  onTap: onRename,
                ),
            ],
          ),
      ],
    );
  }

  Widget _removable(
    BuildContext context,
    EditablePhoto photo,
    List<ViewerPhoto> viewerPhotos,
    int index,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showPhotoViewer(
            context,
            photos: viewerPhotos,
            initialIndex: index,
          ),
          child: photo.thumbnail,
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: photo.onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Color(0xCC000000),
                shape: BoxShape.circle,
              ),
              child: const Icon(FLucideIcons.x, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// 缩略图下的名称；还没起名时是「添加名称」。
class _NameButton extends StatelessWidget {
  const _NameButton({
    required this.name,
    required this.width,
    required this.onTap,
  });

  final String name;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 2),
          child: Text(
            name.isEmpty ? '添加名称' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: name.isEmpty ? colors.inactive : colors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

final _picker = ImagePicker();

/// 拍一张或从相册多选。取消返回空列表；打不开时弹错误提示并返回空列表。
Future<List<XFile>> pickPhotos(BuildContext context, ImageSource source) async {
  try {
    if (source == ImageSource.camera) {
      final shot = await _picker.pickImage(source: source);
      return shot == null ? const [] : [shot];
    }
    return await _picker.pickMultiImage();
  } on Exception catch (error) {
    if (context.mounted) {
      showAppToast(
        context,
        message: source == ImageSource.camera ? '无法打开相机' : '无法打开相册',
        description: '$error',
        level: AppToastLevel.error,
      );
    }
    return const [];
  }
}
