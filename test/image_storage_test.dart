import 'dart:io';
import 'dart:math';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligy_medical/core/media/image_storage.dart';

/// 替掉原生压缩：缩略图只需要「生成了一个文件」，原图那条路径绝不能经过它。
class _FakeCompress extends FlutterImageCompressPlatform {
  final sources = <String>[];

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

void main() {
  late Directory root;
  late _FakeCompress compress;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ligy_medical_image');
    compress = _FakeCompress();
    FlutterImageCompressPlatform.instance = compress;
  });

  tearDown(() => root.delete(recursive: true));

  test('原图逐字节原样保存，扩展名保留，只有缩略图经过压缩', () async {
    final bytes = List.generate(300000, (_) => Random(7).nextInt(256));
    final source = File('${root.path}/IMG_2026.PNG')..writeAsBytesSync(bytes);
    final storage = ImageStorage.atRoot('${root.path}/support');

    final stored = await storage.storeImage(
      sourcePath: source.path,
      recordId: 'r1',
      attachmentId: 'a1',
    );

    final original = await storage.resolve(stored.imagePath);
    expect(stored.imagePath, endsWith('a1.png'));
    expect(await original.readAsBytes(), bytes, reason: '原图不能被压缩或转码');
    expect(stored.sizeBytes, bytes.length);
    expect(await (await storage.resolve(stored.thumbnailPath)).exists(), isTrue);
    expect(compress.sources, [original.path], reason: '只有缩略图从原图生成');
  });
}
