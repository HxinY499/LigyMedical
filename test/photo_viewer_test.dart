import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ligy_medical/shared/widgets/photo_viewer.dart';

/// 一张永远解码不完的原图，模拟几千万像素照片还在解码的那段时间。
class _SlowImage extends ImageProvider<_SlowImage> {
  @override
  Future<_SlowImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_SlowImage key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

/// 1×1 透明 PNG。
final _pixel = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  testWidgets('原图还没解码出来时先显示缩略图，不是一片黑', (tester) async {
    final preview = MemoryImage(_pixel);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPhotoViewer(
              context,
              photos: [ViewerPhoto(image: _SlowImage(), preview: preview)],
            ),
            child: const Text('看图'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('看图'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images.map((image) => image.image), contains(preview));
    final original = images.firstWhere((image) => image.image != preview);
    expect(original.image, isA<ResizeImage>(), reason: '超大原图限制解码尺寸');
    expect((original.image as ResizeImage).imageProvider, isA<_SlowImage>());
  });
}
