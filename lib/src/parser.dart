import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:http/http.dart' as http;

import 'errors.dart';
import 'format/movie_decoder.dart';
import 'io/cache.dart';
import 'io/fetcher.dart';
import 'model.dart';

/// Loads SVGA animations from the network, the asset bundle or memory.
///
/// Every method either returns a playable [MovieEntity] or throws an
/// [SVGAException] describing what went wrong; nothing else escapes.
class SVGAParser {
  const SVGAParser();

  static const SVGAParser shared = SVGAParser();

  /// Timeout applied to downloads that do not pass their own. `null`
  /// disables the limit.
  static Duration? defaultTimeout = const Duration(seconds: 30);

  /// Files at least this large are decoded on a background isolate so the
  /// UI thread never stalls on a big animation. Smaller files are decoded
  /// inline, which is faster than starting an isolate.
  static int isolateThreshold = 64 * 1024;

  /// The HTTP client used for downloads. Replace it to add authentication,
  /// a proxy or a mock; set `null` to return to the default.
  static http.Client get httpClient => SVGAFetcher.client;
  static set httpClient(http.Client? client) => SVGAFetcher.client = client;

  /// Downloads and decodes the animation at [url].
  ///
  /// With [useCache] (the default) the file is read from [SVGACache] when
  /// present and stored there after a successful download. A cached file
  /// that turns out to be unreadable is discarded and downloaded again, so
  /// a bad entry heals itself.
  Future<MovieEntity> decodeFromURL(
    String url, {
    bool useCache = true,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    if (useCache) {
      final cached = await SVGACache.shared.getRawBytes(url);
      if (cached != null) {
        try {
          return await decodeFromBuffer(cached);
        } on SVGAFormatException {
          await SVGACache.shared.remove(url);
        }
      }
    }

    final bytes = await SVGAFetcher.fetch(
      url,
      headers: headers,
      timeout: timeout ?? defaultTimeout,
    );
    final MovieEntity movie;
    try {
      movie = await decodeFromBuffer(bytes);
    } on SVGAFormatException catch (error) {
      throw error.withSource(url);
    }
    // Stored only after a successful decode, so an error page served with
    // status 200 can never end up in the cache.
    if (useCache) await SVGACache.shared.putRawBytes(url, bytes);
    return movie;
  }

  /// Decodes an animation bundled with the app.
  ///
  /// Assets are already on the device, so they are read straight from the
  /// bundle and never copied into the disk cache.
  Future<MovieEntity> decodeFromAssets(
    String path, {
    AssetBundle? bundle,
    String? package,
  }) async {
    final key = package == null ? path : 'packages/$package/$path';
    final Uint8List bytes;
    try {
      final data = await (bundle ?? rootBundle).load(key);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (error) {
      throw SVGAAssetException(
        'The asset could not be loaded',
        source: key,
        cause: error,
      );
    }
    try {
      return await decodeFromBuffer(bytes);
    } on SVGAFormatException catch (error) {
      throw error.withSource(key);
    }
  }

  /// Decodes an animation from the bytes of an `.svga` file.
  Future<MovieEntity> decodeFromBuffer(List<int> bytes) async {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final DecodedMovie decoded;
    if (kIsWeb || data.length < isolateThreshold) {
      decoded = decodeMovie(data);
    } else {
      try {
        decoded = await compute(decodeMovie, data, debugLabel: 'svga-decode');
      } on SVGAException {
        rethrow;
      } catch (error) {
        throw SVGAFormatException(
          'The file is truncated or corrupt',
          cause: error,
        );
      }
    }
    return _prepareResources(decoded);
  }

  /// Decodes the embedded bitmaps and separates out the sounds.
  Future<MovieEntity> _prepareResources(DecodedMovie decoded) async {
    final movie = decoded.movie;
    final audioKeys = {for (final audio in movie.audios) audio.audioKey};

    await Future.wait(
      decoded.resources.entries.map((resource) async {
        final key = resource.key;
        final bytes = resource.value;
        if (audioKeys.contains(key) || _looksLikeMp3(bytes)) {
          // Copied, because the view would otherwise keep the whole
          // inflated file alive for as long as the sound is.
          movie.audiosData[key] = Uint8List.fromList(bytes);
          return;
        }
        final image = await _decodeImage(key, bytes);
        if (image != null) movie.bitmapCache[key] = image;
      }),
    );
    return movie;
  }

  static Future<ui.Image?> _decodeImage(String key, Uint8List bytes) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await ui.instantiateImageCodecFromBuffer(buffer);
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (error) {
      // One undecodable layer should not take the whole animation down;
      // the layer is simply left out.
      assert(() {
        debugPrint(
          'SVGA: skipped image "$key" that could not be decoded: '
          '$error',
        );
        return true;
      }());
      return null;
    }
  }

  static bool _looksLikeMp3(Uint8List bytes) {
    if (bytes.length < 3) return false;
    // "ID3" tag, or an MPEG audio frame sync.
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) return true;
    return bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0;
  }
}
