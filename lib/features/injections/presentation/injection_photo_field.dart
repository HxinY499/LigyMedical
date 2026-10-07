import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../../shared/widgets/editable_photo_grid.dart';
import '../../records/presentation/record_widgets.dart';

/// 注射的照片区：已保存的 + 本次新选的，下面是拍照、相册两个入口。
class InjectionPhotoField extends StatelessWidget {
  const InjectionPhotoField({
    super.key,
    required this.label,
    required this.kept,
    required this.pending,
    required this.onRemoveKept,
    required this.onRemovePending,
    required this.onPicked,
  });

  final String label;
  final List<InjectionPhotoEntry> kept;

  /// 新选照片的源文件路径。
  final List<String> pending;
  final ValueChanged<InjectionPhotoEntry> onRemoveKept;
  final ValueChanged<String> onRemovePending;
  final ValueChanged<List<String>> onPicked;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picked = await pickPhotos(context, source);
    if (picked.isNotEmpty) onPicked([for (final file in picked) file.path]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormSectionLabel(label),
        if (kept.isNotEmpty || pending.isNotEmpty) ...[
          EditablePhotoGrid(
            photos: [
              for (final photo in kept)
                storedEditablePhoto(
                  path: photo.path,
                  thumbnailPath: photo.thumbnailPath,
                  onRemove: () => onRemoveKept(photo),
                ),
              for (final path in pending)
                pendingEditablePhoto(
                  context,
                  sourcePath: path,
                  onRemove: () => onRemovePending(path),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChip(
              label: '拍照',
              icon: FLucideIcons.camera,
              onTap: () => _pick(context, ImageSource.camera),
            ),
            AppChip(
              label: '相册',
              icon: FLucideIcons.image,
              onTap: () => _pick(context, ImageSource.gallery),
            ),
          ],
        ),
      ],
    );
  }
}
