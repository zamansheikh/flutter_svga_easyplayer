import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Hand-assembles small SVGA files for tests, so the decoder and painter can
/// be checked against content whose every byte is known.
class Msg {
  final BytesBuilder _out = BytesBuilder();

  void _varint(int value) {
    var v = value;
    while (v >= 0x80) {
      _out.addByte((v & 0x7f) | 0x80);
      v >>= 7;
    }
    _out.addByte(v);
  }

  Msg int32(int field, int value) {
    _varint(field << 3);
    _varint(value);
    return this;
  }

  Msg float(int field, double value) {
    _varint((field << 3) | 5);
    _out.add(
      (ByteData(4)..setFloat32(0, value, Endian.little)).buffer.asUint8List(),
    );
    return this;
  }

  Msg bytes(int field, List<int> value) {
    _varint((field << 3) | 2);
    _varint(value.length);
    _out.add(value);
    return this;
  }

  Msg string(int field, String value) => bytes(field, utf8.encode(value));

  Msg message(int field, Msg value) => bytes(field, value.build());

  Uint8List build() => _out.toBytes();
}

Msg rgba(double r, double g, double b, double a) =>
    Msg().float(1, r).float(2, g).float(3, b).float(4, a);

Msg transform(double a, double b, double c, double d, double tx, double ty) =>
    Msg()
        .float(1, a)
        .float(2, b)
        .float(3, c)
        .float(4, d)
        .float(5, tx)
        .float(6, ty);

/// Wraps a movie message the way an `.svga` file stores it.
Uint8List svgaFile(Msg movie) => Uint8List.fromList(zlib.encode(movie.build()));

/// A 100×100, 4-frame, 20 fps movie with one vector layer:
///
/// * frame 0 — a red rect covering the left half
/// * frame 1 — "keep the previous shapes"
/// * frame 2 — a blue path triangle and a dashed green ellipse outline
/// * frame 3 — nothing stored at all (hidden)
Uint8List vectorMovie() {
  final redRect = Msg()
      .int32(1, 1) // RECT
      .message(3, Msg().float(1, 0).float(2, 0).float(3, 50).float(4, 100))
      .message(10, Msg().message(1, rgba(1, 0, 0, 1)));
  final keep = Msg().int32(1, 3);
  final triangle = Msg()
      .int32(1, 0) // SHAPE
      .message(2, Msg().string(1, 'M0 0 L100 0 L100 100 Z'))
      .message(10, Msg().message(1, rgba(0, 0, 1, 1)));
  final ellipse = Msg()
      .int32(1, 2) // ELLIPSE
      .message(4, Msg().float(1, 50).float(2, 50).float(3, 20).float(4, 10))
      .message(
        10,
        Msg()
            .message(2, rgba(0, 1, 0, 1))
            .float(3, 2)
            .int32(4, 1)
            .int32(5, 2)
            .float(6, 4)
            .float(7, 5)
            .float(8, 3)
            .float(9, 1),
      );

  Msg frame(List<Msg> shapes) {
    final message = Msg()
        .float(1, 1)
        .message(2, Msg().float(3, 100).float(4, 100))
        .message(3, transform(1, 0, 0, 1, 0, 0));
    for (final shape in shapes) {
      message.message(5, shape);
    }
    return message;
  }

  final sprite = Msg()
      .string(1, 'layer.vector')
      .message(2, frame([redRect]))
      .message(2, frame([keep]))
      .message(2, frame([triangle, ellipse]))
      .message(2, Msg());

  return svgaFile(
    Msg()
        .string(1, '2.0.0')
        .message(2, Msg().float(1, 100).float(2, 100).int32(3, 20).int32(4, 4))
        .message(4, sprite),
  );
}
