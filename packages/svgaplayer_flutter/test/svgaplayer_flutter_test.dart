import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:svgaplayer_flutter/proto/svga.pb.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('正确导出共享的 SVGA 解析器', () {
    expect(SVGAParser.shared, isA<SVGAParser>());
  });

  for (final disableAnimations in <bool>[true, false]) {
    testWidgets(
      '3 秒动画不会被压缩播放（disableAnimations=$disableAnimations）',
      (tester) async {
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(disableAnimations: disableAnimations);
        addTearDown(() {
          tester.binding.platformDispatcher
              .clearAccessibilityFeaturesTestValue();
        });

        final controller = SVGAAnimationController(vsync: tester)
          ..videoItem = MovieEntity(
            params: MovieParams(fps: 20, frames: 60),
          );
        addTearDown(controller.dispose);

        controller.forward();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 180));
        expect(controller.isCompleted, isFalse);

        await tester.pump(const Duration(milliseconds: 2821));
        expect(controller.isCompleted, isTrue);
      },
    );
  }

  testWidgets('统一解析出口释放原始图片字节并保留渲染数据', (tester) async {
    final decodedImage = await _createImage();
    final parser = SVGAParser(imageDecoder: (_) async => decodedImage);
    final source = MovieEntity(
      params: MovieParams(
        viewBoxWidth: 1,
        viewBoxHeight: 1,
        fps: 20,
        frames: 1,
      ),
      images: <String, List<int>>{
        'hero': <int>[1, 2, 3],
      },
      sprites: <SpriteEntity>[
        SpriteEntity(imageKey: 'hero', frames: <FrameEntity>[FrameEntity()]),
      ],
    );

    final movie = await parser.decodeFromBuffer(_encode(source));
    addTearDown(movie.dispose);

    expect(movie.images, isEmpty);
    expect(movie.bitmapCache['hero'], same(decodedImage));
    expect(movie.sprites.single.imageKey, 'hero');
    expect(movie.sprites.single.frames, hasLength(1));

    final replacement = await _createImage();
    addTearDown(replacement.dispose);
    movie.dynamicItem.setImage(replacement, 'hero');
    expect(movie.dynamicItem.dynamicImages['hero'], same(replacement));
    expect(movie.bitmapCache['hero'], same(decodedImage));
    expect(movie.images, isEmpty);
  });

  testWidgets('任一图片解码失败会回收此前创建但未交付的图片', (tester) async {
    final firstImage = await _createImage();
    var decodeCount = 0;
    final disposedImages = <ui.Image>[];
    final parser = SVGAParser(
      imageDecoder: (_) async {
        decodeCount++;
        if (decodeCount == 2) throw const FormatException('invalid image');
        return firstImage;
      },
      imageDisposer: (image) {
        disposedImages.add(image);
        image.dispose();
      },
    );
    final source = MovieEntity(
      images: <String, List<int>>{
        'first': <int>[1],
        'broken': <int>[2],
      },
    );

    await expectLater(
      parser.decodeFromBuffer(_encode(source)),
      throwsA(isA<FormatException>()),
    );
    expect(decodeCount, 2);
    expect(disposedImages, <ui.Image>[firstImage]);
  });
}

List<int> _encode(MovieEntity movie) {
  return const ZLibEncoder().encode(movie.writeToBuffer());
}

Future<ui.Image> _createImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFFFFFFFF), ui.BlendMode.src);
  return recorder.endRecording().toImage(1, 1);
}
