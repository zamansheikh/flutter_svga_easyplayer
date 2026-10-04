import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:meta/meta.dart';

import 'dynamic_entity.dart';
import 'format/vector_path.dart';

/// Canvas size and timing of an SVGA animation.
class MovieParams {
  const MovieParams({
    this.viewBoxWidth = 0,
    this.viewBoxHeight = 0,
    this.fps = 0,
    this.frames = 0,
  });

  final double viewBoxWidth;
  final double viewBoxHeight;

  /// Frames per second as stored in the file; `0` means "unspecified".
  final int fps;

  /// Total number of frames.
  final int frames;
}

/// A sound embedded in an SVGA animation and the frame range it covers.
class AudioEntity {
  const AudioEntity({
    this.audioKey = '',
    this.startFrame = 0,
    this.endFrame = 0,
    this.startTime = 0,
    this.totalTime = 0,
  });

  final String audioKey;
  final int startFrame;
  final int endFrame;

  /// Offset into the sound, in milliseconds, at which playback begins.
  final int startTime;

  /// Length of the sound in milliseconds.
  final int totalTime;
}

/// A 2D affine transform: `[a c tx; b d ty; 0 0 1]`.
class SVGATransform {
  const SVGATransform(this.a, this.b, this.c, this.d, this.tx, this.ty);

  final double a, b, c, d, tx, ty;
}

enum SVGAShapeType { shape, rect, ellipse, keep }

enum SVGALineCap { butt, round, square }

enum SVGALineJoin { miter, round, bevel }

/// Fill and stroke of a [ShapeEntity]. Colour channels are in `0.0–1.0`.
class SVGAShapeStyle {
  const SVGAShapeStyle({
    this.fillR = 0,
    this.fillG = 0,
    this.fillB = 0,
    this.fillA = 0,
    this.strokeR = 0,
    this.strokeG = 0,
    this.strokeB = 0,
    this.strokeA = 0,
    this.strokeWidth = 0,
    this.lineCap = SVGALineCap.butt,
    this.lineJoin = SVGALineJoin.miter,
    this.miterLimit = 0,
    this.dashOn = 0,
    this.dashOff = 0,
    this.dashPhase = 0,
  });

  final double fillR, fillG, fillB, fillA;
  final double strokeR, strokeG, strokeB, strokeA;
  final double strokeWidth;
  final SVGALineCap lineCap;
  final SVGALineJoin lineJoin;
  final double miterLimit;
  final double dashOn, dashOff, dashPhase;

  bool get hasFill => fillA > 0;
  bool get hasStroke => strokeWidth > 0 && strokeA > 0;
  bool get isDashed => dashOn > 0 || dashOff > 0;
}

/// One vector shape drawn by a sprite on a given frame.
class ShapeEntity {
  ShapeEntity({
    required this.type,
    this.outline,
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.cornerRadius = 0,
    this.style,
    this.transform,
  });

  final SVGAShapeType type;

  /// The outline for [SVGAShapeType.shape]; shared between every shape in
  /// the file that uses the same path text.
  final SVGAVectorPath? outline;

  /// Geometry for rects (`x`, `y`, `width`, `height`, `cornerRadius`) and
  /// ellipses (centre `x`, `y` and radii in `width`, `height`).
  final double x, y, width, height, cornerRadius;

  final SVGAShapeStyle? style;
  final SVGATransform? transform;

  /// SVG path text for [SVGAShapeType.shape], empty otherwise.
  String get d => outline?.source ?? '';

  // Engine objects, created on first paint and reused on every later frame.
  ui.Path? _path;
  bool _pathResolved = false;
  @internal
  ui.Path? dashedPathCache;
  @internal
  ui.Paint? fillPaintCache;
  @internal
  ui.Paint? strokePaintCache;
  @internal
  int fillAlphaCache = -1;
  @internal
  int strokeAlphaCache = -1;

  /// The engine path for this shape, or `null` if it draws nothing.
  ui.Path? get path {
    if (_pathResolved) return _path;
    _pathResolved = true;
    switch (type) {
      case SVGAShapeType.shape:
        final outline = this.outline;
        if (outline != null && !outline.isEmpty) _path = outline.path;
      case SVGAShapeType.rect:
        if (width > 0 && height > 0) {
          _path = ui.Path()
            ..addRRect(
              ui.RRect.fromRectAndRadius(
                ui.Rect.fromLTWH(x, y, width, height),
                ui.Radius.circular(cornerRadius),
              ),
            );
        }
      case SVGAShapeType.ellipse:
        if (width > 0 && height > 0) {
          _path = ui.Path()
            ..addOval(
              ui.Rect.fromLTWH(x - width, y - height, width * 2, height * 2),
            );
        }
      case SVGAShapeType.keep:
        break;
    }
    return _path;
  }
}

/// What one sprite looks like on one frame.
class FrameEntity {
  const FrameEntity({
    this.alpha = 0,
    this.x = 0,
    this.y = 0,
    this.width = 0,
    this.height = 0,
    this.transform,
    this.clip,
    this.shapes = const [],
  });

  /// A sprite that is absent on this frame.
  static const FrameEntity hidden = FrameEntity();

  /// Opacity in `0.0–1.0`. A frame with no stored alpha is invisible.
  final double alpha;

  /// Layout box of the sprite's bitmap.
  final double x, y, width, height;

  final SVGATransform? transform;

  /// Clipping outline, when the sprite is masked on this frame.
  final SVGAVectorPath? clip;

  final List<ShapeEntity> shapes;

  /// SVG path text of the clip, empty when there is none.
  String get clipPath => clip?.source ?? '';

  bool get isVisible => alpha > 0;
}

/// A layer of the animation: one bitmap and/or set of shapes, with its state
/// on every frame.
class SpriteEntity {
  const SpriteEntity({
    required this.imageKey,
    required this.frames,
    this.matteKey = '',
  });

  final String imageKey;
  final String matteKey;
  final List<FrameEntity> frames;
}

/// A decoded SVGA animation, ready to hand to an `SVGAAnimationController`.
class MovieEntity {
  MovieEntity({
    required this.version,
    required this.params,
    required this.sprites,
    required this.audios,
  });

  /// SVGA format version recorded in the file, for example `2.0.0`.
  final String version;
  final MovieParams params;
  final List<SpriteEntity> sprites;
  final List<AudioEntity> audios;

  /// When `true` (the default), the controller that plays this movie
  /// disposes it when it is replaced or the controller is disposed. Set to
  /// `false` to keep one decoded movie alive across several controllers and
  /// call [dispose] yourself.
  bool autorelease = true;

  /// Runtime replacements: swap images, add text, hide layers or draw on top.
  final SVGADynamicEntity dynamicItem = SVGADynamicEntity();

  /// Decoded bitmaps keyed by sprite image key.
  final Map<String, ui.Image> bitmapCache = {};

  /// Encoded sounds keyed by audio key.
  final Map<String, Uint8List> audiosData = {};

  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// Approximate memory held by the decoded bitmaps, in bytes.
  int get bitmapBytes {
    var total = 0;
    for (final image in bitmapCache.values) {
      total += image.width * image.height * 4;
    }
    return total;
  }

  /// Releases the decoded bitmaps and sounds. The movie cannot be played
  /// afterwards.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final image in bitmapCache.values) {
      image.dispose();
    }
    bitmapCache.clear();
    audiosData.clear();
  }
}
