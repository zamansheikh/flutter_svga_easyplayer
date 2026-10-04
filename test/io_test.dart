import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final Uint8List _svga = File('example/assets/kiss.svga').readAsBytesSync();
final Uint8List _html = Uint8List.fromList('<html>oops</html>'.codeUnits);

const _url = 'https://cdn.example.com/a.svga';

void main() {
  late Directory directory;
  final cache = SVGACache.shared;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('svga_cache_test');
    cache
      ..debugUseDirectory(directory)
      ..setEnabled(true)
      ..setMaxAge(const Duration(days: 7))
      ..setMaxCacheSize(100 * 1024 * 1024);
  });

  tearDown(() {
    SVGAParser.httpClient = null;
    cache.debugUseDirectory(null);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });

  /// Installs a mock server and returns the list of requested URLs.
  List<String> serve(FutureOr<http.Response> Function(http.Request) handler) {
    final requests = <String>[];
    SVGAParser.httpClient = MockClient((request) async {
      requests.add(request.url.toString());
      return handler(request);
    });
    return requests;
  }

  group('SVGACache', () {
    test('stores, finds and returns bytes', () async {
      expect(await cache.contains(_url), isFalse);
      expect(await cache.getRawBytes(_url), isNull);

      await cache.putRawBytes(_url, _svga);

      expect(await cache.contains(_url), isTrue);
      expect(await cache.getRawBytes(_url), _svga);
      expect(await cache.getCacheSize(), _svga.length);
      final stats = await cache.getStats();
      expect(stats['fileCount'], 1);
      expect(stats['size'], _svga.length);
      expect(stats['available'], isTrue);
    });

    test('leaves no temporary files behind', () async {
      await cache.putRawBytes(_url, _svga);
      final names = directory.listSync().map((e) => e.path).toList();
      expect(names, hasLength(1));
      expect(names.single, endsWith('.svga'));
    });

    test(
      'a fresh instance sees and clears files from an earlier run',
      () async {
        await cache.putRawBytes(_url, _svga);
        // Simulate an app restart: drop the in-memory index, keep the files.
        cache.debugUseDirectory(directory);

        expect(await cache.getCacheSize(), _svga.length);
        await cache.clear();
        expect(await cache.getCacheSize(), 0);
        expect(directory.listSync(), isEmpty);
      },
    );

    test('remove deletes one entry', () async {
      await cache.putRawBytes(_url, _svga);
      await cache.putRawBytes('$_url?2', _svga);
      await cache.remove(_url);
      expect(await cache.contains(_url), isFalse);
      expect(await cache.contains('$_url?2'), isTrue);
    });

    test('expired entries are not returned and are deleted', () async {
      await cache.putRawBytes(_url, _svga);
      cache.setMaxAge(const Duration(microseconds: 1));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(await cache.contains(_url), isFalse);
      expect(await cache.getRawBytes(_url), isNull);
      expect(directory.listSync(), isEmpty);
    });

    test('evicts the least recently used entry when over the limit', () async {
      cache.setMaxCacheSize(_svga.length * 2 + 10);
      await cache.putRawBytes('a', _svga);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await cache.putRawBytes('b', _svga);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // Reading "a" makes "b" the least recently used.
      await cache.getRawBytes('a');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await cache.putRawBytes('c', _svga);

      expect(await cache.contains('a'), isTrue);
      expect(await cache.contains('b'), isFalse);
      expect(await cache.contains('c'), isTrue);
      expect(await cache.getCacheSize(), _svga.length * 2);
    });

    test('a file larger than the whole cache is not stored', () async {
      cache.setMaxCacheSize(10);
      await cache.putRawBytes(_url, _svga);
      expect(await cache.contains(_url), isFalse);
    });

    test('disabled cache reads and writes nothing', () async {
      cache.setEnabled(false);
      await cache.putRawBytes(_url, _svga);
      expect(await cache.contains(_url), isFalse);
      expect(directory.listSync(), isEmpty);
    });

    test('survives a file deleted behind its back', () async {
      await cache.putRawBytes(_url, _svga);
      directory.listSync().single.deleteSync();
      expect(await cache.getRawBytes(_url), isNull);
      expect(await cache.getCacheSize(), 0);
    });
  });

  group('SVGAParser.decodeFromURL', () {
    test('downloads, decodes and caches', () async {
      final requests = serve((_) => http.Response.bytes(_svga, 200));

      final first = await SVGAParser.shared.decodeFromURL(_url);
      addTearDown(first.dispose);
      expect(first.params.frames, 50);
      expect(await cache.contains(_url), isTrue);

      final second = await SVGAParser.shared.decodeFromURL(_url);
      addTearDown(second.dispose);
      expect(requests, hasLength(1), reason: 'second load is served by cache');
    });

    test('an HTTP error is typed and never cached', () async {
      serve((_) => http.Response('nope', 404));
      await expectLater(
        SVGAParser.shared.decodeFromURL(_url),
        throwsA(
          isA<SVGANetworkException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.source, 'source', _url),
        ),
      );
      expect(await cache.contains(_url), isFalse);
    });

    test('a 200 response that is not SVGA is typed and never cached', () async {
      serve((_) => http.Response.bytes(_html, 200));
      await expectLater(
        SVGAParser.shared.decodeFromURL(_url),
        throwsA(
          isA<SVGAFormatException>().having((e) => e.source, 'source', _url),
        ),
      );
      expect(await cache.contains(_url), isFalse);
    });

    test('a connection failure is a network error without a status', () async {
      serve((_) => throw const SocketException('offline'));
      await expectLater(
        SVGAParser.shared.decodeFromURL(_url),
        throwsA(
          isA<SVGANetworkException>().having(
            (e) => e.statusCode,
            'statusCode',
            isNull,
          ),
        ),
      );
    });

    test('a slow server times out', () async {
      serve((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response.bytes(_svga, 200);
      });
      await expectLater(
        SVGAParser.shared.decodeFromURL(
          _url,
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(isA<SVGATimeoutException>()),
      );
    });

    test('an invalid URL fails without a request', () async {
      final requests = serve((_) => http.Response.bytes(_svga, 200));
      await expectLater(
        SVGAParser.shared.decodeFromURL('not a url'),
        throwsA(isA<SVGANetworkException>()),
      );
      expect(requests, isEmpty);
    });

    test('a poisoned cache entry is discarded and re-downloaded', () async {
      await cache.putRawBytes(_url, _html);
      final requests = serve((_) => http.Response.bytes(_svga, 200));

      final movie = await SVGAParser.shared.decodeFromURL(_url);
      addTearDown(movie.dispose);

      expect(requests, hasLength(1));
      expect(await cache.getRawBytes(_url), _svga);
    });

    test('useCache: false neither reads nor writes the cache', () async {
      await cache.putRawBytes(_url, _svga);
      final requests = serve((_) => http.Response.bytes(_svga, 200));

      final movie = await SVGAParser.shared.decodeFromURL(
        _url,
        useCache: false,
      );
      addTearDown(movie.dispose);
      expect(requests, hasLength(1));

      await cache.clear();
      final again = await SVGAParser.shared.decodeFromURL(
        _url,
        useCache: false,
      );
      addTearDown(again.dispose);
      expect(await cache.contains(_url), isFalse);
      expect(cache.isEnabled, isTrue, reason: 'global switch is untouched');
    });

    test('simultaneous loads of one URL share a single download', () async {
      final requests = serve((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response.bytes(_svga, 200);
      });

      final movies = await Future.wait([
        for (var i = 0; i < 5; i++) SVGAParser.shared.decodeFromURL(_url),
      ]);
      for (final movie in movies) {
        movie.dispose();
      }
      expect(requests, hasLength(1));
    });
  });

  group('SVGAPrecacheManager', () {
    final precache = SVGAPrecacheManager.shared;

    test('caches valid files and counts every outcome', () async {
      await cache.putRawBytes('https://x/cached.svga', _svga);
      serve((request) {
        if (request.url.path.endsWith('missing.svga')) {
          return http.Response('', 404);
        }
        if (request.url.path.endsWith('page.svga')) {
          return http.Response.bytes(_html, 200);
        }
        return http.Response.bytes(_svga, 200);
      });

      final progress = <String, bool>{};
      final result = await precache.precache([
        'https://x/cached.svga',
        'https://x/new.svga',
        'https://x/missing.svga',
        'https://x/page.svga',
      ], onProgress: (_, _, source, success) => progress[source] = success);

      expect(result.total, 4);
      expect(result.completed, 4);
      expect(result.cacheHits, 1);
      expect(result.fetched, 1);
      expect(result.failed, 2);
      expect(result.cancelled, isFalse);
      expect(result.isSuccess, isFalse);
      expect(await cache.contains('https://x/new.svga'), isTrue);
      expect(await cache.contains('https://x/page.svga'), isFalse);
      expect(progress['https://x/new.svga'], isTrue);
      expect(progress['https://x/missing.svga'], isFalse);
      expect(precache.isRunning, isFalse);
      expect(precache.activeTasks, 0);
    });

    test('a truncated download is not cached', () async {
      serve(
        (_) => http.Response.bytes(
          Uint8List.sublistView(_svga, 0, _svga.length ~/ 2),
          200,
        ),
      );
      final result = await precache.precache([_url]);
      expect(result.failed, 1);
      expect(await cache.contains(_url), isFalse);
    });

    test('cancel during the start delay stops the batch', () async {
      final requests = serve((_) => http.Response.bytes(_svga, 200));
      final pending = precache.precache([
        _url,
      ], delay: const Duration(milliseconds: 50));
      expect(precache.isRunning, isTrue);
      precache.cancel();

      final result = await pending;
      expect(result.cancelled, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.completed, 0);
      expect(requests, isEmpty);
    });

    test('an empty batch succeeds immediately', () async {
      final result = await precache.precache([]);
      expect(result.total, 0);
      expect(result.isSuccess, isTrue);
    });

    test('a throwing progress callback does not stop the batch', () async {
      serve((_) => http.Response.bytes(_svga, 200));
      final result = await precache.precache([
        'https://x/1.svga',
        'https://x/2.svga',
      ], onProgress: (_, _, _, _) => throw StateError('caller bug'));
      expect(result.fetched, 2);
    });
  });

  group('SVGAMemoryCache', () {
    final memory = SVGAMemoryCache.shared;

    tearDown(() {
      memory
        ..clear()
        ..maxIdleBytes = 32 * 1024 * 1024;
    });

    final withBitmaps = File(
      'example/assets/corgi-cloud.svga',
    ).readAsBytesSync();
    Future<MovieEntity> load() =>
        SVGAParser.shared.decodeFromBuffer(withBitmaps);

    test('concurrent users share one decoded movie', () async {
      var loads = 0;
      Future<MovieEntity> counted() {
        loads++;
        return load();
      }

      final results = await Future.wait([
        memory.acquire('k', counted),
        memory.acquire('k', counted),
      ]);
      expect(loads, 1);
      expect(identical(results[0], results[1]), isTrue);
      expect(results[0].autorelease, isFalse);

      memory.release('k', results[0]);
      expect(results[0].isDisposed, isFalse, reason: 'still in use');
      memory.release('k', results[1]);
      expect(results[0].isDisposed, isFalse, reason: 'kept idle for reuse');
      expect(memory.idleBytes, results[0].bitmapBytes);

      final reused = await memory.acquire('k', counted);
      expect(loads, 1);
      expect(identical(reused, results[0]), isTrue);
      memory.release('k', reused);
    });

    test('idle movies are disposed once over the budget', () async {
      memory.maxIdleBytes = 0;
      final movie = await memory.acquire('k', load);
      memory.release('k', movie);
      expect(movie.isDisposed, isTrue);
      expect(memory.length, 0);
    });

    test('a failed load is not remembered', () async {
      await expectLater(
        memory.acquire('bad', () async => throw const SVGAFormatException('x')),
        throwsA(isA<SVGAFormatException>()),
      );
      expect(memory.length, 0);
      final movie = await memory.acquire('bad', load);
      expect(movie.isDisposed, isFalse);
      memory.release('bad', movie);
    });
  });
}
