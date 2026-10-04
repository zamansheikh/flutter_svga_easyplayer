import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'format/movie_decoder.dart';
import 'io/cache.dart';
import 'io/fetcher.dart';
import 'parser.dart';

/// Called each time one entry of a precache batch finishes.
///
/// * [completed] — entries finished so far, including this one.
/// * [total] — entries in the batch.
/// * [source] — the URL or asset path that just finished.
/// * [success] — whether the entry is now ready to play from cache.
typedef SVGAPrecacheProgress =
    void Function(int completed, int total, String source, bool success);

/// Outcome of a precache batch.
class SVGAPrecacheResult {
  const SVGAPrecacheResult({
    required this.total,
    required this.completed,
    required this.cacheHits,
    required this.fetched,
    required this.failed,
    required this.cancelled,
  });

  /// Entries requested.
  final int total;

  /// Entries processed before the batch ended.
  final int completed;

  /// Entries that were already cached.
  final int cacheHits;

  /// Entries downloaded and stored by this batch.
  final int fetched;

  /// Entries that could not be downloaded or were not valid SVGA files.
  final int failed;

  /// Whether [SVGAPrecacheManager.cancel] stopped the batch early.
  final bool cancelled;

  /// Whether every entry is now cached.
  bool get isSuccess => !cancelled && failed == 0 && completed == total;

  @override
  String toString() =>
      'SVGAPrecacheResult(total: $total, completed: $completed, '
      'hits: $cacheHits, fetched: $fetched, failed: $failed, '
      'cancelled: $cancelled)';
}

/// Downloads SVGA files into [SVGACache] ahead of time, so the first
/// playback of each one starts without waiting for the network.
///
/// ```dart
/// SVGAPrecacheManager.shared.precache(
///   ['https://cdn.example.com/a.svga', 'https://cdn.example.com/b.svga'],
///   delay: const Duration(seconds: 2),
/// );
/// ```
///
/// Precaching never throws: a failed entry is counted in
/// [SVGAPrecacheResult.failed] and the rest of the batch carries on.
class SVGAPrecacheManager {
  SVGAPrecacheManager._();

  static SVGAPrecacheManager? _instance;
  static SVGAPrecacheManager get shared =>
      _instance ??= SVGAPrecacheManager._();

  // Bumped by cancel(). A batch that started under an older epoch stops
  // picking up work, whether it is downloading or still in its start delay.
  int _epoch = 0;
  int _activeTasks = 0;
  int _activeBatches = 0;

  /// Downloads currently in progress.
  int get activeTasks => _activeTasks;

  /// Whether any batch is waiting to start or running.
  bool get isRunning => _activeBatches > 0;

  /// Downloads [urls] into the disk cache.
  ///
  /// * [delay] — wait before starting, to stay out of the way of app
  ///   startup.
  /// * [concurrency] — maximum simultaneous downloads.
  /// * [skipIfCached] — leave entries that are already cached untouched.
  /// * [timeout] — per-download limit; defaults to
  ///   [SVGAParser.defaultTimeout].
  /// * [headers] — extra HTTP headers for every download.
  /// * [onProgress] — called as each entry finishes.
  Future<SVGAPrecacheResult> precache(
    List<String> urls, {
    Duration? delay,
    int concurrency = 3,
    bool skipIfCached = true,
    Duration? timeout,
    Map<String, String>? headers,
    SVGAPrecacheProgress? onProgress,
  }) {
    return _run(
      sources: urls,
      delay: delay,
      concurrency: concurrency,
      onProgress: onProgress,
      process: (url) async {
        if (skipIfCached && await SVGACache.shared.contains(url)) {
          return _Outcome.cacheHit;
        }
        final bytes = await SVGAFetcher.fetch(
          url,
          headers: headers,
          timeout: timeout ?? SVGAParser.defaultTimeout,
        );
        // Inflate the payload off the UI thread to prove it is a complete
        // SVGA file before it is allowed into the cache.
        if (!await compute(isIntactSvga, bytes)) return _Outcome.failed;
        await SVGACache.shared.putRawBytes(url, bytes);
        return _Outcome.fetched;
      },
    );
  }

  /// Checks that the bundled animations at [paths] exist and are valid.
  ///
  /// Assets are read straight from the app bundle at playback time, so
  /// there is nothing to download or store; this is useful as a startup
  /// sanity check. Valid assets are counted as [SVGAPrecacheResult.cacheHits].
  Future<SVGAPrecacheResult> precacheAssets(
    List<String> paths, {
    Duration? delay,
    int concurrency = 3,
    bool skipIfCached = true,
    SVGAPrecacheProgress? onProgress,
  }) {
    return _run(
      sources: paths,
      delay: delay,
      concurrency: concurrency,
      onProgress: onProgress,
      process: (path) async {
        final data = await rootBundle.load(path);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        return looksLikeSvga(bytes) ? _Outcome.cacheHit : _Outcome.failed;
      },
    );
  }

  /// Stops every batch that is waiting or running. Downloads already in
  /// progress finish; no new ones start.
  void cancel() {
    _epoch++;
  }

  Future<SVGAPrecacheResult> _run({
    required List<String> sources,
    required Duration? delay,
    required int concurrency,
    required SVGAPrecacheProgress? onProgress,
    required Future<_Outcome> Function(String source) process,
  }) async {
    final total = sources.length;
    var completed = 0, hits = 0, fetched = 0, failed = 0;
    final epoch = _epoch;
    bool isCancelled() => epoch != _epoch;

    SVGAPrecacheResult result() => SVGAPrecacheResult(
      total: total,
      completed: completed,
      cacheHits: hits,
      fetched: fetched,
      failed: failed,
      cancelled: isCancelled() && completed < total,
    );

    if (total == 0) return result();

    _activeBatches++;
    try {
      if (delay != null && delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      var next = 0;
      Future<void> worker() async {
        while (!isCancelled() && next < total) {
          final source = sources[next++];
          var outcome = _Outcome.failed;
          _activeTasks++;
          try {
            outcome = await process(source);
          } catch (_) {
            // Network, storage and asset errors all count as a failed
            // entry; one bad source must not stop the batch.
          } finally {
            _activeTasks--;
          }
          switch (outcome) {
            case _Outcome.cacheHit:
              hits++;
            case _Outcome.fetched:
              fetched++;
            case _Outcome.failed:
              failed++;
          }
          completed++;
          try {
            onProgress?.call(
              completed,
              total,
              source,
              outcome != _Outcome.failed,
            );
          } catch (_) {
            // A throwing callback is the caller's bug, not a reason to
            // abandon the remaining downloads.
          }
        }
      }

      await Future.wait(
        List.generate(concurrency.clamp(1, total), (_) => worker()),
      );
    } finally {
      _activeBatches--;
    }
    return result();
  }
}

enum _Outcome { cacheHit, fetched, failed }
