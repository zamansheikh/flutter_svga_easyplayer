import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:flutter_svga_easyplayer/src/format/movie_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/svga_builder.dart';

Uint8List fixture(String name) =>
    File('example/assets/$name.svga').readAsBytesSync();

void main() {
  group('decodeMovie', () {
    test('reads the structure of a real file', () {
      final decoded = decodeMovie(fixture('kiss'));
      final movie = decoded.movie;

      expect(movie.version, '2.1.0');
      expect(movie.params.frames, 50);
      expect(movie.params.fps, 20);
      expect(movie.params.viewBoxWidth, 750);
      expect(movie.params.viewBoxHeight, 1334);
      expect(movie.sprites, hasLength(10));
      for (final sprite in movie.sprites) {
        expect(sprite.frames, hasLength(movie.params.frames));
      }
      expect(decoded.resources, hasLength(4));
    });

    test('every bundled gift decodes, with its embedded files', () {
      final files = Directory('example/assets')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.svga'))
          .toList();
      expect(files, hasLength(10));
      for (final file in files) {
        final decoded = decodeMovie(file.readAsBytesSync());
        expect(decoded.movie.params.frames, greaterThan(0), reason: file.path);
        expect(decoded.resources, isNotEmpty, reason: file.path);
      }
    });

    test('finds the sounds in a gift that has them', () {
      final decoded = decodeMovie(fixture('slipper-slap'));
      expect(decoded.movie.audios, hasLength(7));
      for (final audio in decoded.movie.audios) {
        expect(decoded.resources, contains(audio.audioKey));
      }
    });

    test('reads vector shapes, styles and transforms', () {
      final movie = decodeMovie(vectorMovie()).movie;
      expect(movie.params.frames, 4);
      final frames = movie.sprites.single.frames;
      expect(movie.sprites.single.imageKey, 'layer.vector');

      final rect = frames[0].shapes.single;
      expect(rect.type, SVGAShapeType.rect);
      expect(rect.width, 50);
      expect(rect.height, 100);
      expect(rect.style!.hasFill, isTrue);
      expect(rect.style!.fillR, 1);
      expect(rect.style!.hasStroke, isFalse);
      expect(rect.path!.getBounds().width, 50);
      expect(frames[0].alpha, 1);
      expect(frames[0].transform!.a, 1);
      expect(frames[0].isVisible, isTrue);

      final triangle = frames[2].shapes[0];
      expect(triangle.type, SVGAShapeType.shape);
      expect(triangle.d, 'M0 0 L100 0 L100 100 Z');

      final ellipse = frames[2].shapes[1];
      expect(ellipse.type, SVGAShapeType.ellipse);
      final style = ellipse.style!;
      expect(style.hasFill, isFalse);
      expect(style.hasStroke, isTrue);
      expect(style.strokeWidth, 2);
      expect(style.lineCap, SVGALineCap.round);
      expect(style.lineJoin, SVGALineJoin.bevel);
      expect(style.miterLimit, 4);
      expect(style.isDashed, isTrue);
      expect([style.dashOn, style.dashOff, style.dashPhase], [5, 3, 1]);
      expect(ellipse.path!.getBounds().width, 40);
      expect(ellipse.path!.getBounds().height, 20);
    });

    test('a "keep" frame reuses the previous frame\'s shapes', () {
      final frames = decodeMovie(vectorMovie()).movie.sprites.single.frames;
      expect(identical(frames[1].shapes, frames[0].shapes), isTrue);
    });

    test('a frame with nothing stored is hidden', () {
      final frames = decodeMovie(vectorMovie()).movie.sprites.single.frames;
      expect(frames[3].isVisible, isFalse);
      expect(frames[3].shapes, isEmpty);
    });

    test('frames that repeat an outline share one compiled path', () {
      final triangle = Msg()
          .int32(1, 0)
          .message(2, Msg().string(1, 'M0 0 L9 0 L9 9 Z'));
      final frame = Msg().float(1, 1).message(5, triangle);
      final movie = decodeMovie(
        svgaFile(
          Msg()
              .message(2, Msg().float(1, 9).float(2, 9).int32(4, 2))
              .message(
                4,
                Msg().string(1, 'a').message(2, frame).message(2, frame),
              ),
        ),
      ).movie;
      final frames = movie.sprites.single.frames;
      expect(
        identical(
          frames[0].shapes.single.outline,
          frames[1].shapes.single.outline,
        ),
        isTrue,
      );
    });

    test('unknown fields are skipped, not fatal', () {
      final movie = decodeMovie(
        svgaFile(
          Msg()
              .int32(15, 7)
              .string(16, 'future field')
              .message(
                2,
                Msg().float(1, 1).float(2, 1).int32(4, 1).float(9, 2),
              ),
        ),
      ).movie;
      expect(movie.params.frames, 1);
    });

    test('a movie with no frames is rejected', () {
      expect(
        () => decodeMovie(svgaFile(Msg().string(1, '2.0.0'))),
        throwsA(isA<SVGAFormatException>()),
      );
    });

    test('rejects an empty file', () {
      expect(
        () => decodeMovie(Uint8List(0)),
        throwsA(isA<SVGAFormatException>()),
      );
    });

    test('rejects an HTML error page', () {
      final html = Uint8List.fromList('<html>Not Found</html>'.codeUnits);
      expect(looksLikeSvga(html), isFalse);
      expect(() => decodeMovie(html), throwsA(isA<SVGAFormatException>()));
    });

    test('names SVGA 1.x ZIP files in the error', () {
      final zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]);
      expect(
        () => decodeMovie(zip),
        throwsA(
          isA<SVGAFormatException>().having(
            (e) => e.message,
            'message',
            contains('1.x'),
          ),
        ),
      );
    });

    test('rejects a truncated file', () {
      final bytes = fixture('kiss');
      final truncated = Uint8List.sublistView(bytes, 0, bytes.length ~/ 2);
      expect(looksLikeSvga(truncated), isTrue);
      expect(isIntactSvga(truncated), isFalse);
      expect(() => decodeMovie(truncated), throwsA(isA<SVGAFormatException>()));
    });

    test('accepts an intact file', () {
      expect(isIntactSvga(fixture('kiss')), isTrue);
    });
  });

  group('SVGAParser.decodeFromBuffer', () {
    for (final name in ['corgi-cloud', 'blue-rose-heart']) {
      test('decodes $name inline and on an isolate identically', () async {
        final bytes = fixture(name);
        final previous = SVGAParser.isolateThreshold;
        addTearDown(() => SVGAParser.isolateThreshold = previous);

        SVGAParser.isolateThreshold = 1 << 40;
        final inline = await SVGAParser.shared.decodeFromBuffer(bytes);
        SVGAParser.isolateThreshold = 0;
        final isolated = await SVGAParser.shared.decodeFromBuffer(bytes);
        addTearDown(inline.dispose);
        addTearDown(isolated.dispose);

        expect(isolated.params.frames, inline.params.frames);
        expect(isolated.sprites.length, inline.sprites.length);
        expect(
          isolated.bitmapCache.keys,
          unorderedEquals(inline.bitmapCache.keys),
        );
        expect(inline.bitmapCache, isNotEmpty);
        expect(inline.bitmapBytes, greaterThan(0));
      });
    }

    test('reports a corrupt file from the isolate as a format error', () async {
      final previous = SVGAParser.isolateThreshold;
      addTearDown(() => SVGAParser.isolateThreshold = previous);
      SVGAParser.isolateThreshold = 0;
      final bytes = fixture('kiss');
      await expectLater(
        SVGAParser.shared.decodeFromBuffer(
          Uint8List.sublistView(bytes, 0, bytes.length ~/ 2),
        ),
        throwsA(isA<SVGAFormatException>()),
      );
    });

    test('disposing a movie releases its bitmaps', () async {
      final movie = await SVGAParser.shared.decodeFromBuffer(fixture('kiss'));
      movie.dispose();
      expect(movie.isDisposed, isTrue);
      expect(movie.bitmapCache, isEmpty);
      movie.dispose(); // A second call is harmless.
    });
  });

  group('SVGAVectorPath', () {
    test('absolute and relative commands reach the same outline', () {
      final absolute = SVGAVectorPath.parse('M10 10 L30 10 L30 40 Z');
      final relative = SVGAVectorPath.parse('m10,10 l20,0 l0,30 z');
      expect(absolute.path.getBounds(), relative.path.getBounds());
      expect(absolute.path.getBounds().width, 20);
      expect(absolute.path.getBounds().height, 30);
    });

    test('handles compact numbers, exponents and implicit repeats', () {
      final path = SVGAVectorPath.parse('M0 0L1e1-.5 20 5.5H40V-10');
      final bounds = path.path.getBounds();
      expect(bounds.left, 0);
      expect(bounds.right, 40);
      expect(bounds.top, -10);
      expect(bounds.bottom, 5.5);
    });

    test('curves and smooth curves are accepted', () {
      final path = SVGAVectorPath.parse(
        'M0 0 C0 10 10 10 10 0 S20 -10 20 0 Q25 10 30 0 T40 0',
      );
      expect(path.isEmpty, isFalse);
      expect(path.path.getBounds().right, 40);
    });

    test('relative commands after a close start from the sub-path origin', () {
      final path = SVGAVectorPath.parse('M10 10 L20 10 L20 20 Z l-5 0');
      expect(path.path.getBounds().left, 5);
    });

    test('garbage produces an empty outline instead of throwing', () {
      expect(SVGAVectorPath.parse('').isEmpty, isTrue);
      expect(SVGAVectorPath.parse('12 34').isEmpty, isTrue);
      expect(SVGAVectorPath.parse('M abc').isEmpty, isTrue);
    });
  });
}
