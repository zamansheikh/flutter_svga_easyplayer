// Benchmark, not a test: run explicitly with
//   flutter test test/benchmark/render_bench.dart
//
// Measures decode time and the Dart-side cost of painting every frame through
// the public API only, so the same file can compare implementations. Nothing
// is rasterized in the test environment, so GPU time is not included.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every animation bundled with the example app.
final List<String> _files = [
  for (final file in Directory('example/assets').listSync())
    if (file.path.endsWith('.svga'))
      file.uri.pathSegments.last.replaceAll('.svga', ''),
]..sort();
const _decodeRuns = 5;
const _paintPasses = 5;

double _median(List<int> micros) {
  final sorted = [...micros]..sort();
  return sorted[sorted.length ~/ 2] / 1000.0;
}

void main() {
  for (final name in _files) {
    testWidgets('bench $name', (tester) async {
      final bytes = File('example/assets/$name.svga').readAsBytesSync();

      // Decode twice over: inline on the UI isolate, then on a background
      // isolate, so the threshold between the two can be chosen from data.
      final inlineTimes = <int>[];
      final isolateTimes = <int>[];
      MovieEntity? movie;
      for (final (threshold, times) in [
        (1 << 40, inlineTimes),
        (0, isolateTimes),
      ]) {
        SVGAParser.isolateThreshold = threshold;
        for (var i = 0; i < _decodeRuns; i++) {
          final sw = Stopwatch()..start();
          final decoded = await tester.runAsync(
            () => SVGAParser.shared.decodeFromBuffer(bytes),
          );
          sw.stop();
          times.add(sw.elapsedMicroseconds);
          movie?.dispose();
          movie = decoded;
        }
      }

      final controller = SVGAAnimationController(vsync: tester)
        ..videoItem = movie;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: SVGAImage(controller, clearsAfterStop: false),
            ),
          ),
        ),
      );

      final frames = controller.frames;
      final passTimes = <int>[];
      for (var pass = 0; pass < _paintPasses + 1; pass++) {
        final sw = Stopwatch()..start();
        for (var f = 0; f < frames; f++) {
          controller.value = (f + 0.5) / frames;
          await tester.pump();
        }
        sw.stop();
        // First pass warms the path cache and the JIT.
        if (pass > 0) passTimes.add(sw.elapsedMicroseconds);
      }

      final paintMs = _median(passTimes);
      // ignore: avoid_print
      print(
        'BENCH ${name.padRight(20)} '
        'size=${(bytes.length / 1024).toStringAsFixed(0).padLeft(5)}KB '
        'frames=${frames.toString().padLeft(4)} '
        'sprites=${movie!.sprites.length.toString().padLeft(4)} '
        'decodeInline=${_median(inlineTimes).toStringAsFixed(1).padLeft(6)}ms '
        'decodeIsolate=${_median(isolateTimes).toStringAsFixed(1).padLeft(6)}ms '
        'paintAll=${paintMs.toStringAsFixed(1).padLeft(7)}ms '
        'perFrame=${(paintMs * 1000 / frames).toStringAsFixed(0).padLeft(5)}us',
      );

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
