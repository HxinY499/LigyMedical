import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class StoredImage {
  const StoredImage({
    required this.imagePath,
    required this.thumbnailPath,
    required this.width,
    required this.height,
    required this.sizeBytes,
  });

  final String imagePath;
  final String thumbnailPath;
  final int width;
  final int height;
  final int sizeBytes;
}

class StoredFile {
  const StoredFile({required this.path, required this.sizeBytes});

  final String path;
  final int sizeBytes;
}

/// 记录附件的落盘。库里只存相对 support 目录的路径。
///
/// 目录结构：`media/{recordId}/{attachmentId}.jpg|_thumb.jpg|.pdf`。
/// 删记录时整目录清掉即可。
class ImageStorage {
  ImageStorage() : _overrideRoot = null;

  /// 把根目录指到一个给定路径（测试用）。
  ImageStorage.atRoot(String root) : _overrideRoot = root;

  final String? _overrideRoot;

  /// support 目录的绝对路径缓存。
  ///
  /// 拿这个目录要走一次 platform channel，列表里的缩略图每次重建都异步查一遍
  /// 会闪一下，所以进程内缓存一份，配合 [warmUp] 让渲染路径变成同步的。
  static String? _supportPath;

  /// 预热 support 目录缓存，使 [resolveSyncPath] 可用。应用启动时调用一次。
  static Future<void> warmUp() async {
    _supportPath ??= (await getApplicationSupportDirectory()).path;
  }

  /// 同步拼出绝对路径。未预热时返回 null，调用方需回退到异步的 [resolve]。
  static String? resolveSyncPath(String relativePath) {
    final root = _supportPath;
    return root == null ? null : p.join(root, relativePath);
  }

  Future<String> _supportRoot() async {
    final override = _overrideRoot;
    if (override != null) return override;
    return _supportPath ??= (await getApplicationSupportDirectory()).path;
  }

  /// 所有相对路径的根。备份恢复要在它下面建暂存目录、整体换 media 目录。
  Future<String> supportRoot() => _supportRoot();

  Future<Directory> _recordDirectory(String recordId) async {
    final directory = Directory(
      p.join(await _supportRoot(), kMediaDirName, recordId),
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<StoredImage> storeImage({
    required String sourcePath,
    required String recordId,
    required String attachmentId,
  }) async {
    final directory = await _recordDirectory(recordId);
    final imageFile = File(p.join(directory.path, '$attachmentId.jpg'));
    final thumbnailFile = File(
      p.join(directory.path, '${attachmentId}_thumb.jpg'),
    );
    // 报告要能放大看清小字，长边比账单图留得更宽。
    final compressed = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      imageFile.path,
      minWidth: 2560,
      minHeight: 2560,
      quality: 88,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (compressed == null) {
      throw StateError('图片压缩失败');
    }

    final thumbnail = await FlutterImageCompress.compressAndGetFile(
      compressed.path,
      thumbnailFile.path,
      minWidth: 320,
      minHeight: 320,
      quality: 76,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    if (thumbnail == null) {
      await imageFile.delete();
      throw StateError('缩略图生成失败');
    }

    final bytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final support = await _supportRoot();
    final result = StoredImage(
      imagePath: p.relative(imageFile.path, from: support),
      thumbnailPath: p.relative(thumbnailFile.path, from: support),
      width: frame.image.width,
      height: frame.image.height,
      sizeBytes: await imageFile.length(),
    );
    frame.image.dispose();
    codec.dispose();
    return result;
  }

  /// 原样拷贝一份文件（PDF）。不做任何转码：报告文件必须和医院给的一致。
  Future<StoredFile> storeFile({
    required String sourcePath,
    required String recordId,
    required String attachmentId,
    required String extension,
  }) async {
    final directory = await _recordDirectory(recordId);
    final target = File(p.join(directory.path, '$attachmentId.$extension'));
    await File(sourcePath).copy(target.path);
    return StoredFile(
      path: p.relative(target.path, from: await _supportRoot()),
      sizeBytes: await target.length(),
    );
  }

  Future<File> resolve(String relativePath) async {
    return File(p.join(await _supportRoot(), relativePath));
  }

  Future<void> deleteFile(String relativePath) async {
    final file = await resolve(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteRecordDirectory(String recordId) async {
    final directory = Directory(
      p.join(await _supportRoot(), kMediaDirName, recordId),
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

/// 附件根目录名（相对 support 目录）。
const kMediaDirName = 'media';
