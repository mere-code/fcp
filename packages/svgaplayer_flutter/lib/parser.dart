import 'dart:developer';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show Uint8List, kReleaseMode;
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

  /// Releases decoded bitmaps that cannot be delivered after a parse failure.
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

    final decodedImages = <String, ui.Image>{};
    try {
      for (final item in images.entries) {
        decodedImages[item.key] = await _decodeImageItem(
          item.key,
          Uint8List.fromList(item.value),
          timeline: timeline,
        );
      }
    } catch (_) {
      for (final image in decodedImages.values) {
        imageDisposer(image);
      }
      rethrow;
    }

    movieItem.bitmapCache.addAll(decodedImages);
    images.clear();
    return movieItem;
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
