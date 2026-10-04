import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/svga_builder.dart';

/// Serves the example app's animations as if they were bundled assets.
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final file = File('example/assets/$key');
    if (!file.existsSync()) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(file.readAsBytesSync());
  }
}

Widget _host(Widget child) => DefaultAssetBundle(
  bundle: _FileBundle(),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: SizedBox(width: 120, height: 120, child: child)),
  ),
);

/// Lets real I/O, isolate work and image decoding finish, then rebuilds.
///
/// A load is a chain of real asynchronous steps whose continuations run in
/// the test's fake-async zone, so each step needs real time to complete and
/// then a pump to run what follows it.
Future<void> _settleLoad(WidgetTester tester) async {
  for (var round = 0; round < 8; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
}

Future<MovieEntity> _decode(WidgetTester tester, String name) async {
  final bytes = File('example/assets/$name.svga').readAsBytesSync();
  return (await tester.runAsync(
    () => SVGAParser.shared.decodeFromBuffer(bytes),
  ))!;
}

void main() {
  // The previous test's widgets are disposed after its tearDown, which
  // returns their animations to the cache; start each test from empty.
  setUp(SVGAMemoryCache.shared.clear);
  tearDown(SVGAMemoryCache.shared.clear);

  group('SVGAAnimationController', () {
    testWidgets('takes its length from the movie', (tester) async {
      final movie = await _decode(tester, 'kiss');
      final controller = SVGAAnimationController(vsync: tester);
      addTearDown(controller.dispose);

      expect(controller.frames, 0);
      expect(controller.currentFrame, 0);

      controller.videoItem = movie;
      expect(controller.frames, 50);
      expect(controller.duration, greaterThan(Duration.zero));

      controller.value = 0.5;
      expect(controller.currentFrame, 25);
      controller.value = 1.0;
      expect(controller.currentFrame, 49);
    });

    testWidgets('disposes a movie it owns, keeps one it does not', (
      tester,
    ) async {
      final owned = await _decode(tester, 'kiss');
      final borrowed = await _decode(tester, 'kiss')
        ..autorelease = false;

      final controller = SVGAAnimationController(vsync: tester)
        ..videoItem = owned;
      controller.videoItem = borrowed;
      expect(owned.isDisposed, isTrue);

      controller.dispose();
      expect(borrowed.isDisposed, isFalse);
      borrowed.dispose();
    });

    testWidgets('volume is clamped and mute keeps it', (tester) async {
      final controller = SVGAAnimationController(vsync: tester);
      addTearDown(controller.dispose);
      controller.volume = 3;
      expect(controller.volume, 1.0);
      controller.volume = 0.4;
      controller.muted = true;
      expect(controller.volume, 0.4);
      expect(controller.muted, isTrue);
    });
  });

  group('SVGAImage', () {
    testWidgets('repaints once per frame, not once per tick', (tester) async {
      // One layer, visible on frames 0 and 1, so each paint calls the
      // drawer exactly once.
      final movie = (await tester.runAsync(
        () => SVGAParser.shared.decodeFromBuffer(vectorMovie()),
      ))!;
      final controller = SVGAAnimationController(vsync: tester)
        ..videoItem = movie;
      addTearDown(controller.dispose);
      final visible = movie.sprites.single;
      var paints = 0;
      movie.dynamicItem.setDynamicDrawer((_, _) => paints++, visible.imageKey);

      await tester.pumpWidget(
        _host(SVGAImage(controller, clearsAfterStop: false)),
      );
      expect(paints, 1);

      // Three ticks that all land inside frame 0.
      for (final value in [0.001, 0.002, 0.003]) {
        controller.value = value;
        await tester.pump();
      }
      expect(paints, 1);

      controller.value = 1.5 / controller.frames;
      await tester.pump();
      expect(paints, 2);

      controller.clear();
      await tester.pump();
      expect(paints, 2, reason: 'a cleared canvas draws nothing');
    });

    testWidgets('draws vector shapes in their colours', (tester) async {
      final movie = (await tester.runAsync(
        () => SVGAParser.shared.decodeFromBuffer(vectorMovie()),
      ))!;
      final controller = SVGAAnimationController(vsync: tester)
        ..videoItem = movie;
      addTearDown(controller.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 100,
                height: 100,
                child: SVGAImage(controller, clearsAfterStop: false),
              ),
            ),
          ),
        ),
      );

      /// RGBA of the pixel at ([x], [y]) on the given frame.
      Future<List<int>> pixel(int frame, int x, int y) async {
        controller.value = (frame + 0.5) / controller.frames;
        await tester.pump();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final data = (await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData();
          image.dispose();
          return bytes!;
        }))!;
        final offset = (y * 100 + x) * 4;
        return [for (var i = 0; i < 4; i++) data.getUint8(offset + i)];
      }

      // Frame 0: red rect on the left half only.
      expect(await pixel(0, 25, 50), [255, 0, 0, 255]);
      expect(await pixel(0, 75, 50), [0, 0, 0, 0]);
      // Frame 1 keeps the previous shapes.
      expect(await pixel(1, 25, 50), [255, 0, 0, 255]);
      // Frame 2: blue triangle in the top-right, nothing bottom-left.
      expect(await pixel(2, 90, 10), [0, 0, 255, 255]);
      expect(await pixel(2, 10, 90), [0, 0, 0, 0]);
      // Frame 3 is hidden.
      expect(await pixel(3, 25, 50), [0, 0, 0, 0]);
      expect(await pixel(3, 90, 10), [0, 0, 0, 0]);
    });

    testWidgets('takes no space without a movie', (tester) async {
      final controller = SVGAAnimationController(vsync: tester);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(SVGAImage(controller)));
      expect(find.byType(CustomPaint), findsNothing);
    });
  });

  group('SVGAEasyPlayer', () {
    testWidgets('shows the placeholder, then the animation', (tester) async {
      MovieEntity? loaded;
      await tester.pumpWidget(
        _host(
          SVGAEasyPlayer.asset(
            'kiss.svga',
            placeholder: const Text('loading'),
            onLoaded: (movie) => loaded = movie,
          ),
        ),
      );
      expect(find.text('loading'), findsOneWidget);

      await _settleLoad(tester);
      expect(find.text('loading'), findsNothing);
      expect(find.byType(SVGAImage), findsOneWidget);
      expect(loaded, isNotNull);
    });

    testWidgets('a failed load shows the error widget and reports it', (
      tester,
    ) async {
      Object? reported;
      await tester.pumpWidget(
        _host(
          SVGAEasyPlayer.asset(
            'missing.svga',
            errorBuilder: (_, error) => const Text('failed'),
            onError: (error, _) => reported = error,
          ),
        ),
      );
      await _settleLoad(tester);

      expect(find.text('failed'), findsOneWidget);
      expect(reported, isA<SVGAAssetException>());
    });

    testWidgets('a file that is not SVGA is a format error', (tester) async {
      Object? reported;
      await tester.pumpWidget(
        _host(
          SVGAEasyPlayer.asset(
            // A real file in the same folder, but not an animation.
            '../pubspec.yaml',
            onError: (error, _) => reported = error,
          ),
        ),
      );
      await _settleLoad(tester);
      expect(reported, isA<SVGAFormatException>());
    });

    /// Pumps in 50 ms steps until [isDone], returning the elapsed time.
    Future<Duration> pumpUntil(
      WidgetTester tester,
      bool Function() isDone,
    ) async {
      const step = Duration(milliseconds: 50);
      var elapsed = Duration.zero;
      while (!isDone() && elapsed < const Duration(seconds: 60)) {
        await tester.pump(step);
        elapsed += step;
      }
      return elapsed;
    }

    testWidgets('playCount: 1 plays once and finishes once', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        _host(
          SVGAEasyPlayer.asset(
            'kiss.svga',
            playCount: 1,
            onFinished: () => finished++,
          ),
        ),
      );
      await _settleLoad(tester);

      await pumpUntil(tester, () => finished > 0);
      expect(finished, 1);
      await tester.pump(const Duration(seconds: 10));
      expect(finished, 1);
    });

    testWidgets('playCount: 3 plays three times', (tester) async {
      Future<Duration> timeToFinish(int playCount) async {
        var finished = false;
        await tester.pumpWidget(
          _host(
            SVGAEasyPlayer(
              key: ValueKey(playCount),
              assetsName: 'kiss.svga',
              playCount: playCount,
              onFinished: () => finished = true,
            ),
          ),
        );
        await _settleLoad(tester);
        return pumpUntil(tester, () => finished);
      }

      final once = await timeToFinish(1);
      final thrice = await timeToFinish(3);
      expect(thrice.inMilliseconds / once.inMilliseconds, closeTo(3.0, 0.25));
    });

    testWidgets('onFinished alone plays once', (tester) async {
      var finished = 0;
      await tester.pumpWidget(
        _host(SVGAEasyPlayer.asset('kiss.svga', onFinished: () => finished++)),
      );
      await _settleLoad(tester);
      await pumpUntil(tester, () => finished > 0);
      expect(finished, 1);
      await tester.pump(const Duration(seconds: 10));
      expect(finished, 1);
    });

    testWidgets('without playCount or onFinished it repeats forever', (
      tester,
    ) async {
      MovieEntity? movie;
      var paints = 0;
      await tester.pumpWidget(
        _host(
          SVGAEasyPlayer.asset(
            'kiss.svga',
            useCache: false,
            onLoaded: (loaded) => movie = loaded,
          ),
        ),
      );
      await _settleLoad(tester);
      for (final sprite in movie!.sprites) {
        movie!.dynamicItem.setDynamicDrawer(
          (_, _) => paints++,
          sprite.imageKey,
        );
      }
      // Far beyond one play (2.5 s): it must still be animating.
      await tester.pump(const Duration(seconds: 30));
      paints = 0;
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(paints, greaterThan(0));
    });

    testWidgets('the original constructor still repeats forever', (
      tester,
    ) async {
      var finished = 0;
      await tester.pumpWidget(
        _host(
          SVGAEasyPlayer(
            // ignore: deprecated_member_use_from_same_package
            assetsName: 'kiss.svga',
            onFinished: () => finished++,
          ),
        ),
      );
      await _settleLoad(tester);
      await tester.pump(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 30));
      expect(finished, 0);
    });

    testWidgets('players of one source share a decoded movie', (tester) async {
      final loaded = <MovieEntity>[];
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: SVGAEasyPlayer.asset(
                    'corgi-cloud.svga',
                    onLoaded: loaded.add,
                  ),
                ),
            ],
          ),
        ),
      );
      await _settleLoad(tester);

      expect(loaded, hasLength(3));
      expect(identical(loaded[0], loaded[1]), isTrue);
      expect(identical(loaded[1], loaded[2]), isTrue);

      // Removing the players keeps the movie idle for the next screen.
      await tester.pumpWidget(const SizedBox());
      expect(loaded[0].isDisposed, isFalse);
      expect(SVGAMemoryCache.shared.idleBytes, loaded[0].bitmapBytes);
    });

    testWidgets('useCache: false gives the player its own movie', (
      tester,
    ) async {
      final loaded = <MovieEntity>[];
      await tester.pumpWidget(
        _host(
          Column(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: SVGAEasyPlayer.asset(
                    'kiss.svga',
                    useCache: false,
                    onLoaded: loaded.add,
                  ),
                ),
            ],
          ),
        ),
      );
      await _settleLoad(tester);

      expect(loaded, hasLength(2));
      expect(identical(loaded[0], loaded[1]), isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(loaded[0].isDisposed, isTrue);
      expect(loaded[1].isDisposed, isTrue);
    });

    testWidgets('changing the source replaces the animation', (tester) async {
      final loaded = <MovieEntity>[];
      Widget player(String asset) =>
          _host(SVGAEasyPlayer.asset(asset, onLoaded: loaded.add));

      await tester.pumpWidget(player('kiss.svga'));
      await _settleLoad(tester);
      await tester.pumpWidget(player('corgi-cloud.svga'));
      await _settleLoad(tester);

      expect(loaded, hasLength(2));
      expect(loaded[0].params.frames, 50);
      expect(loaded[1].params.frames, 96);
      expect(find.byType(SVGAImage), findsOneWidget);
    });

    testWidgets('a source that changes mid-load keeps only the newest', (
      tester,
    ) async {
      final loaded = <MovieEntity>[];
      Widget player(String asset) =>
          _host(SVGAEasyPlayer.asset(asset, onLoaded: loaded.add));

      await tester.pumpWidget(player('corgi-cloud.svga'));
      await tester.pumpWidget(player('kiss.svga'));
      await _settleLoad(tester);

      expect(loaded, hasLength(1));
      expect(loaded.single.params.frames, 50);
    });

    testWidgets('keepLastFrame leaves the animation on screen', (tester) async {
      Future<int> paintsAfterFinish({required bool keepLastFrame}) async {
        var finished = false;
        var paints = 0;
        await tester.pumpWidget(
          _host(
            SVGAEasyPlayer.asset(
              'kiss.svga',
              key: ValueKey(keepLastFrame),
              useCache: false,
              playCount: 1,
              keepLastFrame: keepLastFrame,
              onLoaded: (movie) {
                for (final sprite in movie.sprites) {
                  movie.dynamicItem.setDynamicDrawer(
                    (_, _) => paints++,
                    sprite.imageKey,
                  );
                }
              },
              onFinished: () => finished = true,
            ),
          ),
        );
        await _settleLoad(tester);
        await pumpUntil(tester, () => finished);
        // Force one more paint of whatever is left on the canvas.
        paints = 0;
        tester.renderObject(find.byType(CustomPaint)).markNeedsPaint();
        await tester.pump();
        return paints;
      }

      expect(await paintsAfterFinish(keepLastFrame: true), greaterThan(0));
      expect(await paintsAfterFinish(keepLastFrame: false), 0);
    });

    testWidgets('no source shows nothing and does not throw', (tester) async {
      await tester.pumpWidget(_host(const SVGAEasyPlayer()));
      await _settleLoad(tester);
      expect(find.byType(CustomPaint), findsNothing);
    });
  });
}
