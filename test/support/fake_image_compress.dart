import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// 替掉原生压缩：缩略图只需要「生成了一个文件」，原图那条路径绝不能经过它。
class FakeImageCompress extends FlutterImageCompressPlatform {
  final sources = <String>[];

  /// 装上并返回实例。
  static FakeImageCompress install() {
    final fake = FakeImageCompress();
    FlutterImageCompressPlatform.instance = fake;
    return fake;
  }

  @override
  Future<XFile?> compressAndGetFile(
    String path,
    String targetPath, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    CompressFormat format = CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async {
    sources.add(path);
    await File(targetPath).writeAsBytes([0xFF, 0xD8, 0xFF]);
    return XFile(targetPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
