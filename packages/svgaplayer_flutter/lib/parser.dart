import 'dart:developer';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart'
    show
        ErrorDescription,
        FlutterError,
        FlutterErrorDetails,
        Uint8List,
        kDebugMode,
        kReleaseMode;
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' show get;
import 'package:archive/archive.dart' as archive;
// ignore: import_of_legacy_library_into_null_safe
import 'proto/svga.pbserver.dart';

const _filterKey = 'SVGAParser';

typedef SVGAImageDecoder = Future<ui.Image> Function(Uint8List bytes);
typedef SVGAImageDisposer = void Function(ui.Image image);

void _disposeImage(ui.Image image) => image.dispose();

/// You use SVGAParser to load and decode animation files.
class SVGAParser {
  const SVGAParser({
    this.imageDecoder = decodeImageFromList,
    this.imageDisposer = _disposeImage,
  });

  /// Decodes embedded bitmap bytes. Injectable to support deterministic tests.
  final SVGAImageDecoder imageDecoder;

  /// Releases decoded bitmaps if they cannot be added to the bitmap cache.
  final SVGAImageDisposer imageDisposer;

  static const shared = SVGAParser();

  /// Download animation file from remote server, and decode it.
  Future<MovieEntity> decodeFromURL(String url) async {
    final response = await get(Uri.parse(url));
    return decodeFromBuffer(response.bodyBytes);
  }

  /// Download animation file from bundle assets, and decode it.
  Future<MovieEntity> decodeFromAssets(String path) async {
    return decodeFromBuffer((await rootBundle.load(path)).buffer.asUint8List());
  }

  /// Download animation file from buffer, and decode it.
  Future<MovieEntity> decodeFromBuffer(List<int> bytes) {
    TimelineTask? timeline;
    if (!kReleaseMode) {
      timeline = TimelineTask(filterKey: _filterKey)
        ..start('DecodeFromBuffer', arguments: {'length': bytes.length});
    }
    final inflatedBytes = const archive.ZLibDecoder().decodeBytes(bytes);
    if (timeline != null) {
      timeline.instant('MovieEntity.fromBuffer()',
          arguments: {'inflatedLength': inflatedBytes.length});
    }
    final movie = MovieEntity.fromBuffer(inflatedBytes);
    if (timeline != null) {
      timeline.instant('prepareResources()',
          arguments: {'images': movie.images.keys.join(',')});
    }
    return _prepareResources(
      _processShapeItems(movie),
      timeline: timeline,
    ).whenComplete(() {
      if (timeline != null) timeline.finish();
    });
  }

  MovieEntity _processShapeItems(MovieEntity movieItem) {
    for (final sprite in movieItem.sprites) {
      List<ShapeEntity>? lastShape;
      for (final frame in sprite.frames) {
        if (frame.shapes.isNotEmpty) {
          if (frame.shapes[0].type == ShapeEntity_ShapeType.KEEP &&
              lastShape != null) {
            frame.shapes = lastShape;
          } else if (frame.shapes.isNotEmpty == true) {
            lastShape = frame.shapes;
          }
        }
      }
    }
    return movieItem;
  }

  Future<MovieEntity> _prepareResources(MovieEntity movieItem,
      {TimelineTask? timeline}) async {
    final images = movieItem.images;
    if (images.isEmpty) return movieItem;

    final audioKeys = movieItem.audios.map((audio) => audio.audioKey).toSet();
    for (final audioKey in audioKeys) {
      final bytes = images[audioKey];
      if (bytes != null && bytes.isNotEmpty) {
        movieItem.audioCache[audioKey] = List<int>.from(bytes);
      }
    }

    final decodedImages = <String, ui.Image>{};
    for (final item in images.entries) {
      final bytes = Uint8List.fromList(item.value);
      if (bytes.isEmpty ||
          audioKeys.contains(item.key) ||
          !_looksLikeImage(bytes)) {
        continue;
      }

      try {
        decodedImages[item.key] = await _decodeImageItem(
          item.key,
          bytes,
          timeline: timeline,
        );
      } catch (error, stack) {
        if (kDebugMode) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'svgaplayer',
            context:
                ErrorDescription('while decoding image with key "${item.key}"'),
          ));
        }
      }
    }

    try {
      movieItem.bitmapCache.addAll(decodedImages);
    } catch (_) {
      for (final image in decodedImages.values) {
        imageDisposer(image);
      }
      rethrow;
    }
    images.clear();
    return movieItem;
  }

  bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return true;
    }
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8) {
      return true;
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46) {
      return true;
    }
    return bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50;
  }

  Future<ui.Image> _decodeImageItem(String key, Uint8List bytes,
      {TimelineTask? timeline}) async {
    TimelineTask? task;
    if (!kReleaseMode) {
      task = TimelineTask(filterKey: _filterKey, parent: timeline)
        ..start('DecodeImage', arguments: {'key': key, 'length': bytes.length});
    }
    try {
      final image = await imageDecoder(bytes);
      if (task != null) {
        task.finish(
          arguments: {'imageSize': '${image.width}x${image.height}'},
        );
      }
      return image;
    } catch (e, stack) {
      if (task != null) {
        task.finish(arguments: {'error': '$e', 'stack': '$stack'});
      }
      Error.throwWithStackTrace(e, stack);
    }
  }
}
