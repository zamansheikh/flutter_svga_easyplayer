import 'dart:typed_data';

import 'package:archive/archive.dart' show ZLibDecoder;

import '../errors.dart';
import '../model.dart';
import 'vector_path.dart';
import 'wire_reader.dart';

/// The result of decoding an SVGA file's structure: the movie description
/// plus the still-encoded images and sounds it embeds.
///
/// Everything here is plain Dart data, so it can be produced on a background
/// isolate and handed back to the UI isolate.
class DecodedMovie {
  DecodedMovie(this.movie, this.resources);

  final MovieEntity movie;

  /// Embedded files keyed by image or audio key. The values are views into
  /// the inflated buffer, not copies.
  final Map<String, Uint8List> resources;
}

/// Whether [bytes] start like a zlib stream, which every SVGA 2.x file does.
///
/// Cheap enough to run on any payload before storing or decoding it; it
/// rejects HTML error pages, JSON bodies and ZIP archives outright.
bool looksLikeSvga(Uint8List bytes) {
  if (bytes.length < 2) return false;
  final cmf = bytes[0];
  if (cmf & 0x0F != 8) return false;
  return ((cmf << 8) | bytes[1]) % 31 == 0;
}

/// Inflates [bytes] without interpreting them, to prove the payload is
/// complete and uncorrupted. Returns `false` instead of throwing.
bool isIntactSvga(Uint8List bytes) {
  try {
    return _inflate(bytes).isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Inflates and parses an SVGA 2.x file.
///
/// Throws [SVGAFormatException] for anything that is not a well-formed SVGA
/// file. Safe to call from any isolate.
DecodedMovie decodeMovie(Uint8List bytes) {
  final inflated = _inflate(bytes);
  try {
    return _MovieReader(inflated).read();
  } on SVGAFormatException {
    rethrow;
  } catch (error) {
    // FormatException and RangeError from a malformed message.
    throw SVGAFormatException('The file is truncated or corrupt', cause: error);
  }
}

Uint8List _inflate(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw const SVGAFormatException('The file is empty');
  }
  // Two header bytes plus the four-byte checksum is the least a zlib stream
  // can be.
  if (bytes.length < 6 || !looksLikeSvga(bytes)) {
    final isZip = bytes.length > 1 && bytes[0] == 0x50 && bytes[1] == 0x4B;
    throw SVGAFormatException(
      isZip
          ? 'This is an SVGA 1.x (ZIP) file; only SVGA 2.x is supported'
          : 'Not an SVGA file',
    );
  }

  final Uint8List inflated;
  try {
    inflated = const ZLibDecoder().decodeBytes(bytes);
  } catch (error) {
    throw SVGAFormatException('The file is truncated or corrupt', cause: error);
  }

  // A zlib stream ends with the Adler-32 checksum of the data it holds.
  // Inflating a download that was cut short can still "succeed" with partial
  // output, so the checksum is what actually proves the file is complete.
  final end = bytes.length;
  final expected =
      (bytes[end - 4] << 24) |
      (bytes[end - 3] << 16) |
      (bytes[end - 2] << 8) |
      bytes[end - 1];
  if (_adler32(inflated) != expected) {
    throw const SVGAFormatException('The file is truncated or corrupt');
  }
  return inflated;
}

int _adler32(Uint8List data) {
  const modulus = 65521;
  // The largest run that cannot overflow 32 bits before reducing.
  const run = 5552;
  var a = 1, b = 0;
  var i = 0;
  final length = data.length;
  while (i < length) {
    final stop = i + run < length ? i + run : length;
    for (; i < stop; i++) {
      a += data[i];
      b += a;
    }
    a %= modulus;
    b %= modulus;
  }
  return ((b << 16) | a) & 0xFFFFFFFF;
}

// Field tags: (field number << 3) | wire type.
const int _len1 = 0x0A, _len2 = 0x12, _len3 = 0x1A, _len4 = 0x22, _len5 = 0x2A;
const int _len10 = 0x52, _len11 = 0x5A;
const int _f32_1 = 0x0D, _f32_2 = 0x15, _f32_3 = 0x1D, _f32_4 = 0x25;
const int _f32_5 = 0x2D, _f32_6 = 0x35, _f32_7 = 0x3D, _f32_8 = 0x45;
const int _f32_9 = 0x4D;
const int _int1 = 0x08, _int2 = 0x10, _int3 = 0x18, _int4 = 0x20, _int5 = 0x28;

class _MovieReader {
  _MovieReader(Uint8List inflated) : _r = WireReader(inflated);

  final WireReader _r;

  // Animations repeat the same outline on many frames; share one compiled
  // path per distinct text.
  final Map<String, SVGAVectorPath> _paths = {};

  DecodedMovie read() {
    final r = _r;
    var version = '';
    var params = const MovieParams();
    final resources = <String, Uint8List>{};
    final sprites = <SpriteEntity>[];
    final audios = <AudioEntity>[];

    while (r.hasMore) {
      final tag = r.readVarint();
      switch (tag) {
        case _len1:
          version = r.readString();
        case _len2:
          params = _params();
        case _len3:
          _resource(resources);
        case _len4:
          sprites.add(_sprite());
        case _len5:
          audios.add(_audio());
        default:
          r.skip(tag);
      }
    }

    if (params.frames < 1) {
      throw const SVGAFormatException('The file contains no frames');
    }
    return DecodedMovie(
      MovieEntity(
        version: version,
        params: params,
        sprites: sprites,
        audios: audios,
      ),
      resources,
    );
  }

  SVGAVectorPath _path(String text) =>
      _paths[text] ??= SVGAVectorPath.parse(text);

  MovieParams _params() {
    final r = _r;
    final outer = r.beginMessage();
    double width = 0, height = 0;
    var fps = 0, frames = 0;
    while (r.hasMore) {
      final tag = r.readVarint();
      switch (tag) {
        case _f32_1:
          width = r.readFloat();
        case _f32_2:
          height = r.readFloat();
        case _int3:
          fps = r.readInt32();
        case _int4:
          frames = r.readInt32();
        default:
          r.skip(tag);
      }
    }
    r.endMessage(outer);
    return MovieParams(
      viewBoxWidth: width,
      viewBoxHeight: height,
      fps: fps,
      frames: frames,
    );
  }

  void _resource(Map<String, Uint8List> into) {
    final r = _r;
    final outer = r.beginMessage();
    var key = '';
    Uint8List? value;
    while (r.hasMore) {
      final tag = r.readVarint();
      switch (tag) {
        case _len1:
          key = r.readString();
        case _len2:
          value = r.readBytes();
        default:
          r.skip(tag);
      }
    }
    r.endMessage(outer);
    if (value != null) into[key] = value;
  }

  AudioEntity _audio() {
    final r = _r;
    final outer = r.beginMessage();
    var key = '';
    var startFrame = 0, endFrame = 0, startTime = 0, totalTime = 0;
    while (r.hasMore) {
      final tag = r.readVarint();
      switch (tag) {
        case _len1:
          key = r.readString();
        case _int2:
          startFrame = r.readInt32();
        case _int3:
          endFrame = r.readInt32();
        case _int4:
          startTime = r.readInt32();
        case _int5:
          totalTime = r.readInt32();
        default:
          r.skip(tag);
      }
    }
    r.endMessage(outer);
    return AudioEntity(
      audioKey: key,
      startFrame: startFrame,
      endFrame: endFrame,
      startTime: startTime,
      totalTime: totalTime,
    );
  }

  SpriteEntity _sprite() {
    final r = _r;
    final outer = r.beginMessage();
    var imageKey = '', matteKey = '';
    final frames = <FrameEntity>[];
    // A frame may say "same shapes as the previous frame" instead of
    // repeating them; resolve that here so the painter never has to.
    List<ShapeEntity>? previousShapes;
    while (r.hasMore) {
      final tag = r.readVarint();
      switch (tag) {
        case _len1:
          imageKey = r.readString();
        case _len2:
          final frame = _frame(previousShapes);
          if (frame.shapes.isNotEmpty) previousShapes = frame.shapes;
          frames.add(frame);
        case _len3:
          matteKey = r.readString();
        default:
          r.skip(tag);
      }
    }
    r.endMessage(outer);
    return SpriteEntity(imageKey: imageKey, matteKey: matteKey, frames: frames);
  }

  FrameEntity _frame(List<ShapeEntity>? previousShapes) {
    final r = _r;
    final outer = r.beginMessage();
    if (!r.hasMore) {
      r.endMessage(outer);
      return FrameEntity.hidden;
    }
    double alpha = 0, x = 0, y = 0, width = 0, height = 0;
    SVGATransform? transform;
    SVGAVectorPath? clip;
    List<ShapeEntity>? shapes;
    var keepsPrevious = false;
    while (r.hasMore) {
      final tag = r.readVarint();
      switch (tag) {
        case _f32_1:
          alpha = r.readFloat();
        case _len2:
          final inner = r.beginMessage();
          while (r.hasMore) {
            final field = r.readVarint();
            switch (field) {
              case _f32_1:
                x = r.readFloat();
              case _f32_2:
                y = r.readFloat();
              case _f32_3:
                width = r.readFloat();
              case _f32_4:
                height = r.readFloat();
              default:
                r.skip(field);
            }
          }
          r.endMessage(inner);
        case _len3:
          transform = _transform();
        case _len4:
          final text = r.readString();
          if (text.isNotEmpty) clip = _path(text);
        case _len5:
          final shape = _shape();
          if (shape.type == SVGAShapeType.keep) {
            if (shapes == null) keepsPrevious = true;
          } else {
            (shapes ??= []).add(shape);
          }
        default:
          r.skip(tag);
      }
    }
    r.endMessage(outer);
    return FrameEntity(
      alpha: alpha,
      x: x,
      y: y,
      width: width,
      height: height,
      transform: transform,
      clip: clip,
      shapes: keepsPrevious && shapes == null
          ? (previousShapes ?? const [])
          : (shapes ?? const []),
    );
  }

  SVGATransform _transform() {
    final r = _r;
    final outer = r.beginMessage();
    double a = 0, b = 0, c = 0, d = 0, tx = 0, ty = 0;
    while (r.hasMore) {
      final tag = r.readVarint();
      switch (tag) {
        case _f32_1:
          a = r.readFloat();
        case _f32_2:
          b = r.readFloat();
        case _f32_3:
          c = r.readFloat();
        case _f32_4:
          d = r.readFloat();
        case _f32_5:
          tx = r.readFloat();
        case _f32_6:
          ty = r.readFloat();
        default:
          r.skip(tag);
      }
    }
    r.endMessage(outer);
    return SVGATransform(a, b, c, d, tx, ty);
  }

  ShapeEntity _shape() {
    final r = _r;
    final outer = r.beginMessage();
    var type = SVGAShapeType.shape;
    SVGAVectorPath? outline;
    double x = 0, y = 0, width = 0, height = 0, cornerRadius = 0;
    SVGAShapeStyle? style;
    SVGATransform? transform;
    while (r.hasMore) {
      final tag = r.readVarint();
      switch (tag) {
        case _int1:
          final value = r.readVarint();
          type = value < SVGAShapeType.values.length
              ? SVGAShapeType.values[value]
              : SVGAShapeType.keep;
        case _len2:
          final inner = r.beginMessage();
          while (r.hasMore) {
            final field = r.readVarint();
            if (field == _len1) {
              outline = _path(r.readString());
            } else {
              r.skip(field);
            }
          }
          r.endMessage(inner);
        case _len3 || _len4:
          // Rect: x, y, width, height, cornerRadius.
          // Ellipse: centre x, y, then radii stored as width, height.
          final inner = r.beginMessage();
          while (r.hasMore) {
            final field = r.readVarint();
            switch (field) {
              case _f32_1:
                x = r.readFloat();
              case _f32_2:
                y = r.readFloat();
              case _f32_3:
                width = r.readFloat();
              case _f32_4:
                height = r.readFloat();
              case _f32_5:
                cornerRadius = r.readFloat();
              default:
                r.skip(field);
            }
          }
          r.endMessage(inner);
        case _len10:
          style = _style();
        case _len11:
          transform = _transform();
        default:
          r.skip(tag);
      }
    }
    r.endMessage(outer);
    return ShapeEntity(
      type: type,
      outline: outline,
      x: x,
      y: y,
      width: width,
      height: height,
      cornerRadius: cornerRadius,
      style: style,
      transform: transform,
    );
  }

  SVGAShapeStyle _style() {
    final r = _r;
    final outer = r.beginMessage();
    double fr = 0, fg = 0, fb = 0, fa = 0;
    double sr = 0, sg = 0, sb = 0, sa = 0;
    double strokeWidth = 0, miterLimit = 0;
    double dashOn = 0, dashOff = 0, dashPhase = 0;
    var cap = SVGALineCap.butt;
    var join = SVGALineJoin.miter;
    while (r.hasMore) {
      final tag = r.readVarint();
      switch (tag) {
        case _len1 || _len2:
          final isFill = tag == _len1;
          final inner = r.beginMessage();
          double red = 0, green = 0, blue = 0, alpha = 0;
          while (r.hasMore) {
            final field = r.readVarint();
            switch (field) {
              case _f32_1:
                red = r.readFloat();
              case _f32_2:
                green = r.readFloat();
              case _f32_3:
                blue = r.readFloat();
              case _f32_4:
                alpha = r.readFloat();
              default:
                r.skip(field);
            }
          }
          r.endMessage(inner);
          if (isFill) {
            fr = red;
            fg = green;
            fb = blue;
            fa = alpha;
          } else {
            sr = red;
            sg = green;
            sb = blue;
            sa = alpha;
          }
        case _f32_3:
          strokeWidth = r.readFloat();
        case _int4:
          final value = r.readVarint();
          if (value < SVGALineCap.values.length) {
            cap = SVGALineCap.values[value];
          }
        case _int5:
          final value = r.readVarint();
          if (value < SVGALineJoin.values.length) {
            join = SVGALineJoin.values[value];
          }
        case _f32_6:
          miterLimit = r.readFloat();
        case _f32_7:
          dashOn = r.readFloat();
        case _f32_8:
          dashOff = r.readFloat();
        case _f32_9:
          dashPhase = r.readFloat();
        default:
          r.skip(tag);
      }
    }
    r.endMessage(outer);
    return SVGAShapeStyle(
      fillR: fr,
      fillG: fg,
      fillB: fb,
      fillA: fa,
      strokeR: sr,
      strokeG: sg,
      strokeB: sb,
      strokeA: sa,
      strokeWidth: strokeWidth,
      lineCap: cap,
      lineJoin: join,
      miterLimit: miterLimit,
      dashOn: dashOn,
      dashOff: dashOff,
      dashPhase: dashPhase,
    );
  }
}
