import 'dart:convert';
import 'dart:typed_data';

/// Minimal forward-only reader for the protobuf wire format.
///
/// SVGA 2.x stores its movie description as a protobuf message. Only the
/// handful of wire types that format uses are needed, so this reads them
/// straight out of the buffer without building intermediate message objects.
class WireReader {
  WireReader(Uint8List bytes)
    : _bytes = bytes,
      _data = ByteData.sublistView(bytes),
      _end = bytes.length;

  static const int wireVarint = 0;
  static const int wireFixed64 = 1;
  static const int wireLengthDelimited = 2;
  static const int wireFixed32 = 5;

  final Uint8List _bytes;
  final ByteData _data;
  int _pos = 0;
  int _end;

  /// Whether the current message has unread bytes.
  bool get hasMore => _pos < _end;

  /// Reads a varint, keeping the low 32 bits as an unsigned value.
  int readVarint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (_pos >= _end) throw const FormatException('Truncated varint');
      final byte = _bytes[_pos++];
      if (shift < 32) result |= (byte & 0x7f) << shift;
      if (byte < 0x80) break;
      shift += 7;
      if (shift > 63) throw const FormatException('Malformed varint');
    }
    return result & 0xFFFFFFFF;
  }

  int readInt32() => readVarint().toSigned(32);

  double readFloat() {
    if (_pos + 4 > _end) throw const FormatException('Truncated float');
    final value = _data.getFloat32(_pos, Endian.little);
    _pos += 4;
    return value;
  }

  String readString() {
    final length = _readLength();
    final start = _pos;
    _pos += length;
    return utf8.decode(
      Uint8List.sublistView(_bytes, start, _pos),
      allowMalformed: true,
    );
  }

  /// Returns a view into the underlying buffer; nothing is copied.
  Uint8List readBytes() {
    final length = _readLength();
    final start = _pos;
    _pos += length;
    return Uint8List.sublistView(_bytes, start, _pos);
  }

  /// Narrows the reader to a nested message and returns the outer limit,
  /// which must be handed back to [endMessage].
  int beginMessage() {
    final length = _readLength();
    final outerEnd = _end;
    _end = _pos + length;
    return outerEnd;
  }

  void endMessage(int outerEnd) {
    _pos = _end;
    _end = outerEnd;
  }

  /// Skips a field whose number this reader's caller does not know.
  void skip(int tag) {
    switch (tag & 7) {
      case wireVarint:
        readVarint();
      case wireFixed64:
        _advance(8);
      case wireLengthDelimited:
        _advance(_readLength());
      case wireFixed32:
        _advance(4);
      default:
        throw FormatException('Unsupported wire type ${tag & 7}');
    }
  }

  int _readLength() {
    final length = readVarint();
    if (_pos + length > _end) {
      throw const FormatException('Field runs past the end of its message');
    }
    return length;
  }

  void _advance(int count) {
    if (_pos + count > _end) throw const FormatException('Truncated field');
    _pos += count;
  }
}
