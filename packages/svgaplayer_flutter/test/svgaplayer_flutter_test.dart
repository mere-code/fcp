import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show FlutterError, FlutterErrorDetails;
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

  testWidgets('统一解析出口解码 PNG 并释放原始图片字节', (tester) async {
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
        'hero': _pngBytes(),
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

  testWidgets('音频和空资源不会调用图片解码器', (tester) async {
    final decodedImage = await _createImage();
    var decodeCount = 0;
    final parser = SVGAParser(
      imageDecoder: (_) async {
        decodeCount++;
        return decodedImage;
      },
    );
    final source = MovieEntity(
      images: <String, List<int>>{
        'sound': <int>[0x49, 0x44, 0x33, 0x03],
        'empty': <int>[],
        'hero': _pngBytes(),
      },
      audios: <AudioEntity>[AudioEntity(audioKey: 'sound')],
    );

    final movie = await parser.decodeFromBuffer(_encode(source));
    addTearDown(movie.dispose);

    expect(decodeCount, 1);
    expect(movie.bitmapCache['hero'], same(decodedImage));
    expect(movie.audioCache['sound'], <int>[0x49, 0x44, 0x33, 0x03]);
    expect(movie.images, isEmpty);
  });

  testWidgets('单张图片解码失败不会阻断其他图片', (tester) async {
    final firstImage = await _createImage();
    final lastImage = await _createImage();
    final reportedErrors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = reportedErrors.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    var decodeCount = 0;
    final disposedImages = <ui.Image>[];
    final parser = SVGAParser(
      imageDecoder: (bytes) async {
        decodeCount++;
        if (bytes.last == 1) throw const FormatException('invalid image');
        return bytes.last == 2 ? lastImage : firstImage;
      },
      imageDisposer: (image) {
        disposedImages.add(image);
      },
    );
    final source = MovieEntity(
      images: <String, List<int>>{
        'first': _pngBytes(),
        'broken': _pngBytes(1),
        'last': _pngBytes(2),
      },
    );

    final movie = await parser.decodeFromBuffer(_encode(source));
    addTearDown(movie.dispose);

    expect(decodeCount, 3);
    expect(movie.bitmapCache['first'], same(firstImage));
    expect(movie.bitmapCache['last'], same(lastImage));
    expect(movie.bitmapCache.containsKey('broken'), isFalse);
    expect(reportedErrors, hasLength(1));
    expect(reportedErrors.single.library, 'svgaplayer');
    expect(reportedErrors.single.context.toString(), contains('broken'));
    expect(disposedImages, isEmpty);
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

List<int> _pngBytes([int marker = 0]) {
  return <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, marker];
}
