import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'audio.dart';
import 'model.dart';

/// Drives playback of one [MovieEntity].
///
/// It is an [AnimationController], so `forward`, `repeat`, `stop`, `value`
/// and status listeners all work as usual; the duration is set from the
/// movie's frame count and frame rate when [videoItem] is assigned.
class SVGAAnimationController extends AnimationController {
  SVGAAnimationController({required super.vsync})
    : super(duration: Duration.zero) {
    addListener(_handleValueChanged);
  }

  // An SVGA file with no frame rate plays at this rate.
  static const int _fallbackFps = 20;

  MovieEntity? _videoItem;
  final List<SVGAAudioTrack> _tracks = [];

  // The ticker fires on every display refresh, but the picture only changes
  // when the frame index does. Painters listen to this instead of to the
  // controller, so a 20 fps animation is painted 20 times a second.
  final _Signal _repaint = _Signal();
  final _Signal _movieChanged = _Signal();

  int _lastFrame = -1;
  bool _cleared = false;
  bool _isMute = false;
  double _volume = 1.0;
  bool _isDisposed = false;

  /// The animation being played, or `null`.
  MovieEntity? get videoItem => _videoItem;

  set videoItem(MovieEntity? value) {
    assert(!_isDisposed, '$this has been disposed');
    if (_isDisposed || identical(value, _videoItem)) return;
    if (isAnimating) stop();
    _disposeTracks();

    final previous = _videoItem;
    _videoItem = value;
    if (previous != null && previous.autorelease) previous.dispose();

    if (value == null) {
      duration = Duration.zero;
      _cleared = true;
    } else {
      final params = value.params;
      final fps = params.fps > 0 ? params.fps : _fallbackFps;
      duration = Duration(
        microseconds: math.max(1000, (params.frames * 1e6 / fps).round()),
      );
      for (final audio in value.audios) {
        final data = value.audiosData[audio.audioKey];
        if (data == null) continue;
        _tracks.add(
          SVGAAudioTrack(audio, data)
            ..setVolume(_effectiveVolume)
            ..prepare(),
        );
      }
      _cleared = false;
    }

    reset();
    _lastFrame = currentFrame;
    _movieChanged.notify();
    _repaint.notify();
  }

  /// Index of the frame currently shown; `0` when there is no movie.
  int get currentFrame {
    final total = frames;
    if (total == 0) return 0;
    return math.min(total - 1, math.max(0, (total * value).toInt()));
  }

  /// Total number of frames; `0` when there is no movie.
  int get frames => _videoItem?.params.frames ?? 0;

  /// Whether sound is silenced. The [volume] setting is kept.
  bool get isMute => _isMute;
  set isMute(bool value) {
    if (_isMute == value) return;
    _isMute = value;
    _applyVolume();
  }

  /// Volume of the animation's sound, from `0.0` to `1.0`.
  double get volume => _volume;
  set volume(double value) {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if (_volume == clamped) return;
    _volume = clamped;
    _applyVolume();
  }

  double get _effectiveVolume => _isMute ? 0.0 : _volume;

  void _applyVolume() {
    final volume = _effectiveVolume;
    for (final track in _tracks) {
      track.setVolume(volume);
    }
  }

  /// Blanks the canvas until the animation moves to another frame.
  void clear() {
    if (_isDisposed) return;
    _cleared = true;
    _repaint.notify();
  }

  @override
  void stop({bool canceled = true}) {
    for (final track in _tracks) {
      track.pause();
    }
    super.stop(canceled: canceled);
  }

  void _handleValueChanged() {
    final frame = currentFrame;
    if (frame == _lastFrame && !_cleared) return;
    final wrapped = frame < _lastFrame;
    _lastFrame = frame;
    _cleared = false;
    _syncAudio(frame, restart: wrapped);
    _repaint.notify();
  }

  void _syncAudio(int frame, {required bool restart}) {
    if (_tracks.isEmpty) return;
    final playing = isAnimating;
    for (final track in _tracks) {
      if (!track.covers(frame)) {
        track.stop();
      } else if (playing) {
        // Jumping backwards means a new loop: start the sound over so it
        // stays in step with the picture.
        if (restart) track.stop();
        track.play();
      }
    }
  }

  void _disposeTracks() {
    for (final track in _tracks) {
      track.dispose();
    }
    _tracks.clear();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _disposeTracks();
    final movie = _videoItem;
    _videoItem = null;
    if (movie != null && movie.autorelease) movie.dispose();
    _repaint.dispose();
    _movieChanged.dispose();
    super.dispose();
  }
}

class _Signal extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// Paints the current frame of an [SVGAAnimationController].
class SVGAImage extends StatefulWidget {
  const SVGAImage(
    this._controller, {
    super.key,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.low,
    this.allowDrawingOverflow,
    this.clearsAfterStop = true,
    this.preferredSize,
  });

  final SVGAAnimationController _controller;

  /// How the animation's canvas is fitted into the widget.
  final BoxFit fit;

  /// Sampling quality used for the animation's bitmaps.
  final FilterQuality filterQuality;

  /// Whether the animation may draw outside the widget's bounds. `null`
  /// (the default) and `true` allow it; `false` clips to the bounds.
  final bool? allowDrawingOverflow;

  /// Whether the canvas is blanked when playback completes.
  final bool clearsAfterStop;

  /// The size this widget asks for. Defaults to the animation's canvas size.
  final Size? preferredSize;

  @override
  State<SVGAImage> createState() => _SVGAImageState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Listenable>('controller', _controller));
  }
}

class _SVGAImageState extends State<SVGAImage> {
  @override
  void initState() {
    super.initState();
    _attach(widget._controller);
  }

  @override
  void didUpdateWidget(SVGAImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._controller != widget._controller) {
      _detach(oldWidget._controller);
      _attach(widget._controller);
    }
  }

  @override
  void dispose() {
    _detach(widget._controller);
    super.dispose();
  }

  void _attach(SVGAAnimationController controller) {
    controller._movieChanged.addListener(_handleMovieChanged);
    controller.addStatusListener(_handleStatus);
  }

  void _detach(SVGAAnimationController controller) {
    controller._movieChanged.removeListener(_handleMovieChanged);
    controller.removeStatusListener(_handleStatus);
  }

  void _handleMovieChanged() {
    if (mounted) setState(() {});
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.clearsAfterStop) {
      widget._controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget._controller.videoItem;
    if (movie == null) return const SizedBox.shrink();
    final viewBox = Size(movie.params.viewBoxWidth, movie.params.viewBoxHeight);
    if (viewBox.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      // Keeps the animation's repaints from dirtying whatever surrounds it.
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SVGAPainter(
            widget._controller,
            fit: widget.fit,
            filterQuality: widget.filterQuality,
            clipRect: widget.allowDrawingOverflow == false,
          ),
          size: widget.preferredSize ?? viewBox,
        ),
      ),
    );
  }
}

class _SVGAPainter extends CustomPainter {
  _SVGAPainter(
    this.controller, {
    required this.fit,
    required this.filterQuality,
    required this.clipRect,
  }) : super(repaint: controller._repaint);

  final SVGAAnimationController controller;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final bool clipRect;

  // Canvas.transform copies the matrix, so one scratch buffer serves every
  // sprite and shape on every frame.
  static final Float64List _matrix = Float64List(16)
    ..[10] = 1.0
    ..[15] = 1.0;

  final Paint _bitmapPaint = Paint()..isAntiAlias = true;
  int _bitmapAlpha = -1;

  @override
  void paint(Canvas canvas, Size size) {
    final movie = controller._videoItem;
    if (movie == null ||
        movie.isDisposed ||
        controller._cleared ||
        size.isEmpty) {
      return;
    }
    final viewBox = Size(movie.params.viewBoxWidth, movie.params.viewBoxHeight);
    if (viewBox.isEmpty) return;
    final fitted = applyBoxFit(fit, viewBox, size);
    if (fitted.source.isEmpty) return;
    final sx = fitted.destination.width / fitted.source.width;
    final sy = fitted.destination.height / fitted.source.height;

    canvas.save();
    if (clipRect) canvas.clipRect(Offset.zero & size);
    canvas.translate(
      (size.width - viewBox.width * sx) / 2,
      (size.height - viewBox.height * sy) / 2,
    );
    canvas.scale(sx, sy);
    _bitmapPaint.filterQuality = filterQuality;
    _drawSprites(canvas, movie, controller.currentFrame);
    canvas.restore();
  }

  void _drawSprites(Canvas canvas, MovieEntity movie, int frameIndex) {
    final dynamicItem = movie.dynamicItem;
    final hasDynamics = !dynamicItem.isEmpty;

    for (final sprite in movie.sprites) {
      final key = sprite.imageKey;
      if (key.isEmpty || frameIndex >= sprite.frames.length) continue;
      final frame = sprite.frames[frameIndex];
      if (!frame.isVisible) continue;
      if (hasDynamics && dynamicItem.dynamicHidden[key] == true) continue;

      final transform = frame.transform;
      final clip = frame.clip;
      final saved = transform != null || clip != null;
      if (saved) canvas.save();
      if (transform != null) _applyTransform(canvas, transform);
      if (clip != null) canvas.clipPath(clip.path);

      final alpha = (frame.alpha * 255).toInt().clamp(0, 255);
      final image =
          (hasDynamics ? dynamicItem.dynamicImages[key] : null) ??
          movie.bitmapCache[key];
      if (image != null && frame.width > 0 && frame.height > 0) {
        if (_bitmapAlpha != alpha) {
          _bitmapAlpha = alpha;
          _bitmapPaint.color = Color.fromARGB(alpha, 0, 0, 0);
        }
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(0, 0, frame.width, frame.height),
          _bitmapPaint,
        );
        if (hasDynamics) {
          final text = dynamicItem.dynamicText[key];
          if (text != null) {
            text.paint(
              canvas,
              Offset(
                (frame.width - text.width) / 2,
                (frame.height - text.height) / 2,
              ),
            );
          }
        }
      }

      final shapes = frame.shapes;
      for (var i = 0; i < shapes.length; i++) {
        _drawShape(canvas, shapes[i], alpha);
      }

      if (hasDynamics) {
        dynamicItem.dynamicDrawer[key]?.call(canvas, frameIndex);
      }
      if (saved) canvas.restore();
    }
  }

  void _drawShape(Canvas canvas, ShapeEntity shape, int frameAlpha) {
    final style = shape.style;
    if (style == null) return;
    final path = shape.path;
    if (path == null) return;

    final transform = shape.transform;
    if (transform != null) {
      canvas.save();
      _applyTransform(canvas, transform);
    }

    if (style.hasFill) {
      final paint = shape.fillPaintCache ??= Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill;
      final alpha = (style.fillA * frameAlpha).toInt().clamp(0, 255);
      if (shape.fillAlphaCache != alpha) {
        shape.fillAlphaCache = alpha;
        paint.color = Color.fromARGB(
          alpha,
          _channel(style.fillR),
          _channel(style.fillG),
          _channel(style.fillB),
        );
      }
      canvas.drawPath(path, paint);
    }

    if (style.hasStroke) {
      final paint = shape.strokePaintCache ??= Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.strokeWidth
        ..strokeMiterLimit = style.miterLimit
        ..strokeCap = switch (style.lineCap) {
          SVGALineCap.butt => StrokeCap.butt,
          SVGALineCap.round => StrokeCap.round,
          SVGALineCap.square => StrokeCap.square,
        }
        ..strokeJoin = switch (style.lineJoin) {
          SVGALineJoin.miter => StrokeJoin.miter,
          SVGALineJoin.round => StrokeJoin.round,
          SVGALineJoin.bevel => StrokeJoin.bevel,
        };
      final alpha = (style.strokeA * frameAlpha).toInt().clamp(0, 255);
      if (shape.strokeAlphaCache != alpha) {
        shape.strokeAlphaCache = alpha;
        paint.color = Color.fromARGB(
          alpha,
          _channel(style.strokeR),
          _channel(style.strokeG),
          _channel(style.strokeB),
        );
      }
      canvas.drawPath(
        style.isDashed ? shape.dashedPathCache ??= _dash(path, style) : path,
        paint,
      );
    }

    if (transform != null) canvas.restore();
  }

  static int _channel(double value) => (value * 255).toInt().clamp(0, 255);

  static void _applyTransform(Canvas canvas, SVGATransform t) {
    final m = _matrix;
    m[0] = t.a;
    m[1] = t.b;
    m[4] = t.c;
    m[5] = t.d;
    m[12] = t.tx;
    m[13] = t.ty;
    canvas.transform(m);
  }

  /// Cuts [source] into dashes. Built once per shape and then reused.
  static Path _dash(Path source, SVGAShapeStyle style) {
    final on = math.max(style.dashOn, 1.0);
    final off = math.max(style.dashOff, 0.1);
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = style.dashPhase;
      var draw = true;
      while (distance < metric.length) {
        final length = draw ? on : off;
        if (draw) {
          dashed.addPath(
            metric.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
    return dashed;
  }

  @override
  bool shouldRepaint(_SVGAPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.fit != fit ||
      oldDelegate.filterQuality != filterQuality ||
      oldDelegate.clipRect != clipRect;
}
