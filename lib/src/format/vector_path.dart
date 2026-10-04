import 'dart:typed_data';
import 'dart:ui' as ui;

/// A vector outline from an SVGA file, compiled once and replayed on demand.
///
/// The SVG path text is turned into a flat list of absolute drawing commands
/// while the file is being decoded (which may happen on a background
/// isolate). The engine [ui.Path] is built lazily the first time the outline
/// is drawn and then reused for every later frame.
class SVGAVectorPath {
  SVGAVectorPath._(this.source, this._verbs, this._coords);

  /// Compiles SVG path data such as `M0 0 L10 0 L10 10 Z`.
  ///
  /// Supports move, line, horizontal, vertical, cubic, smooth cubic,
  /// quadratic, smooth quadratic and close commands in both absolute and
  /// relative form. Unknown commands end the outline at that point rather
  /// than failing the whole file.
  factory SVGAVectorPath.parse(String source) {
    final compiler = _PathCompiler(source)..run();
    return SVGAVectorPath._(
      source,
      Uint8List.fromList(compiler.verbs),
      Float64List.fromList(compiler.coords),
    );
  }

  static const int _move = 0;
  static const int _line = 1;
  static const int _cubic = 2;
  static const int _quad = 3;
  static const int _close = 4;

  /// The original path text.
  final String source;

  final Uint8List _verbs;
  final Float64List _coords;
  ui.Path? _path;

  bool get isEmpty => _verbs.isEmpty;

  /// The engine path for this outline. Must be called on the UI isolate.
  ui.Path get path => _path ??= _build();

  ui.Path _build() {
    final path = ui.Path();
    final c = _coords;
    var i = 0;
    for (final verb in _verbs) {
      switch (verb) {
        case _move:
          path.moveTo(c[i], c[i + 1]);
          i += 2;
        case _line:
          path.lineTo(c[i], c[i + 1]);
          i += 2;
        case _cubic:
          path.cubicTo(c[i], c[i + 1], c[i + 2], c[i + 3], c[i + 4], c[i + 5]);
          i += 6;
        case _quad:
          path.quadraticBezierTo(c[i], c[i + 1], c[i + 2], c[i + 3]);
          i += 4;
        case _close:
          path.close();
      }
    }
    return path;
  }
}

class _PathCompiler {
  _PathCompiler(this.text);

  final String text;
  final List<int> verbs = [];
  final List<double> coords = [];

  int _i = 0;

  // Current point, and the start of the current sub-path (where `Z` returns).
  double _x = 0, _y = 0;
  double _startX = 0, _startY = 0;

  // Last control point, kept only while the previous command was a curve of
  // the matching kind; smooth commands reflect it.
  double? _cubicCx, _cubicCy;
  double? _quadCx, _quadCy;

  void run() {
    var command = 0;
    while (true) {
      _skipSeparators();
      if (_i >= text.length) return;
      final unit = text.codeUnitAt(_i);
      if (_isCommand(unit)) {
        command = unit;
        _i++;
        if (command == 0x5A || command == 0x7A) {
          // Z / z
          _closePath();
          continue;
        }
      } else if (command == 0) {
        // Numbers before any command: nothing sensible to draw.
        return;
      } else if (command == 0x4D) {
        // Extra coordinate pairs after a move are implicit lines.
        command = 0x4C;
      } else if (command == 0x6D) {
        command = 0x6C;
      }
      if (!_apply(command)) return;
    }
  }

  bool _apply(int command) {
    final relative = command >= 0x61;
    final dx = relative ? _x : 0.0;
    final dy = relative ? _y : 0.0;
    switch (command) {
      case 0x4D || 0x6D: // M m
        final x = _number(), y = _number();
        if (x == null || y == null) return false;
        _x = x + dx;
        _y = y + dy;
        _startX = _x;
        _startY = _y;
        verbs.add(SVGAVectorPath._move);
        coords
          ..add(_x)
          ..add(_y);
        _forgetControls();
      case 0x4C || 0x6C: // L l
        final x = _number(), y = _number();
        if (x == null || y == null) return false;
        _lineTo(x + dx, y + dy);
      case 0x48 || 0x68: // H h
        final x = _number();
        if (x == null) return false;
        _lineTo(x + dx, _y);
      case 0x56 || 0x76: // V v
        final y = _number();
        if (y == null) return false;
        _lineTo(_x, y + dy);
      case 0x43 || 0x63: // C c
        final x1 = _number(), y1 = _number();
        final x2 = _number(), y2 = _number();
        final x = _number(), y = _number();
        if (x1 == null ||
            y1 == null ||
            x2 == null ||
            y2 == null ||
            x == null ||
            y == null) {
          return false;
        }
        _cubicTo(x1 + dx, y1 + dy, x2 + dx, y2 + dy, x + dx, y + dy);
      case 0x53 || 0x73: // S s
        final x2 = _number(), y2 = _number();
        final x = _number(), y = _number();
        if (x2 == null || y2 == null || x == null || y == null) return false;
        final cx = _cubicCx, cy = _cubicCy;
        _cubicTo(
          cx == null ? _x : 2 * _x - cx,
          cy == null ? _y : 2 * _y - cy,
          x2 + dx,
          y2 + dy,
          x + dx,
          y + dy,
        );
      case 0x51 || 0x71: // Q q
        final x1 = _number(), y1 = _number();
        final x = _number(), y = _number();
        if (x1 == null || y1 == null || x == null || y == null) return false;
        _quadTo(x1 + dx, y1 + dy, x + dx, y + dy);
      case 0x54 || 0x74: // T t
        final x = _number(), y = _number();
        if (x == null || y == null) return false;
        final cx = _quadCx, cy = _quadCy;
        _quadTo(
          cx == null ? _x : 2 * _x - cx,
          cy == null ? _y : 2 * _y - cy,
          x + dx,
          y + dy,
        );
      default:
        return false;
    }
    return true;
  }

  void _lineTo(double x, double y) {
    verbs.add(SVGAVectorPath._line);
    coords
      ..add(x)
      ..add(y);
    _x = x;
    _y = y;
    _forgetControls();
  }

  void _cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x,
    double y,
  ) {
    verbs.add(SVGAVectorPath._cubic);
    coords
      ..add(x1)
      ..add(y1)
      ..add(x2)
      ..add(y2)
      ..add(x)
      ..add(y);
    _x = x;
    _y = y;
    _cubicCx = x2;
    _cubicCy = y2;
    _quadCx = _quadCy = null;
  }

  void _quadTo(double x1, double y1, double x, double y) {
    verbs.add(SVGAVectorPath._quad);
    coords
      ..add(x1)
      ..add(y1)
      ..add(x)
      ..add(y);
    _x = x;
    _y = y;
    _quadCx = x1;
    _quadCy = y1;
    _cubicCx = _cubicCy = null;
  }

  void _closePath() {
    verbs.add(SVGAVectorPath._close);
    _x = _startX;
    _y = _startY;
    _forgetControls();
  }

  void _forgetControls() {
    _cubicCx = _cubicCy = _quadCx = _quadCy = null;
  }

  static bool _isCommand(int unit) {
    // Letters other than `e`/`E`, which belong to exponents.
    final lower = unit | 0x20;
    return lower >= 0x61 && lower <= 0x7A && lower != 0x65;
  }

  void _skipSeparators() {
    while (_i < text.length) {
      final unit = text.codeUnitAt(_i);
      if (unit == 0x20 || unit == 0x2C || (unit >= 0x09 && unit <= 0x0D)) {
        _i++;
      } else {
        break;
      }
    }
  }

  /// Reads the next number, or returns `null` if the text holds none here.
  double? _number() {
    _skipSeparators();
    final start = _i;
    final length = text.length;
    if (_i < length) {
      final sign = text.codeUnitAt(_i);
      if (sign == 0x2B || sign == 0x2D) _i++;
    }
    var digits = 0;
    while (_i < length && _isDigit(text.codeUnitAt(_i))) {
      _i++;
      digits++;
    }
    if (_i < length && text.codeUnitAt(_i) == 0x2E) {
      _i++;
      while (_i < length && _isDigit(text.codeUnitAt(_i))) {
        _i++;
        digits++;
      }
    }
    if (digits == 0) {
      _i = start;
      return null;
    }
    if (_i < length && (text.codeUnitAt(_i) | 0x20) == 0x65) {
      final mark = _i;
      _i++;
      if (_i < length) {
        final sign = text.codeUnitAt(_i);
        if (sign == 0x2B || sign == 0x2D) _i++;
      }
      var exponentDigits = 0;
      while (_i < length && _isDigit(text.codeUnitAt(_i))) {
        _i++;
        exponentDigits++;
      }
      if (exponentDigits == 0) _i = mark;
    }
    return double.tryParse(text.substring(start, _i));
  }

  static bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;
}
