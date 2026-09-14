import 'package:flutter_test/flutter_test.dart';
import 'package:svgaplayer_flutter/svgaplayer_flutter.dart';

void main() {
  test('正确导出共享的 SVGA 解析器', () {
    expect(SVGAParser.shared, isA<SVGAParser>());
  });
}
