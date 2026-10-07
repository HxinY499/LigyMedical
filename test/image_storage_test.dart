import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ligy_medical/core/media/image_storage.dart';

import 'support/fake_image_compress.dart';

void main() {
  late Directory root;
  late FakeImageCompress compress;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('ligy_medical_image');
    compress = FakeImageCompress.install();
  });

  tearDown(() => root.delete(recursive: true));

  test('原图逐字节原样保存，扩展名保留，只有缩略图经过压缩', () async {
    final bytes = List.generate(300000, (_) => Random(7).nextInt(256));
    final source = File('${root.path}/IMG_2026.PNG')..writeAsBytesSync(bytes);
    final storage = ImageStorage.atRoot('${root.path}/support');

    final stored = await storage.storeImage(
      sourcePath: source.path,
      ownerId: 'r1',
      fileId: 'a1',
    );

    final original = await storage.resolve(stored.imagePath);
    expect(stored.imagePath, endsWith('a1.png'));
    expect(await original.readAsBytes(), bytes, reason: '原图不能被压缩或转码');
    expect(stored.sizeBytes, bytes.length);
    expect(
      await (await storage.resolve(stored.thumbnailPath)).exists(),
      isTrue,
    );
    expect(compress.sources, [original.path], reason: '只有缩略图从原图生成');
  });
}
