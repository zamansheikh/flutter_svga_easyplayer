import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'cache.dart';

/// Callback fired each time a precache entry finishes (success or failure).
///
/// * [completed] — number of entries processed so far.
/// * [total] — total entries in the batch.
/// * [source] — the URL or asset path that just finished.
/// * [success] — `true` if the entry is now in cache, `false` on failure.
typedef SVGAPrecacheProgress =
    void Function(int completed, int total, String source, bool success);

/// Summary of a precache run returned by [SVGAPrecacheManager.precache].
class SVGAPrecacheResult {
  final int total;
  final int completed;
  final int cacheHits;
  final int fetched;
  final int failed;
  final bool cancelled;

  const SVGAPrecacheResult({
    required this.total,
    required this.completed,
    required this.cacheHits,
    required this.fetched,
    required this.failed,
    required this.cancelled,
  });

  bool get isSuccess => !cancelled && failed == 0;

  @override
  String toString() =>
      'SVGAPrecacheResult(total: $total, completed: $completed, '
      'hits: $cacheHits, fetched: $fetched, failed: $failed, '
      'cancelled: $cancelled)';
}

/// Silently pre-fetches SVGA files into [SVGACache] so that when
/// [SVGAParser.decodeFromURL] or [SVGAParser.decodeFromAssets] is later called
/// with the same source, playback starts instantly from the local cache.
///
/// Typical usage at app startup:
///
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///   // Fire-and-forget: warms the cache in the background.
///   SVGAPrecacheManager.shared.precache(
///     ['https://cdn.example.com/a.svga', 'https://cdn.example.com/b.svga'],
///     delay: const Duration(seconds: 2),
///     concurrency: 3,
///   );
///   runApp(MyApp());
/// }
/// ```
///
/// The manager honours [SVGACache.shared] settings (enabled flag, max size,
/// max age) and skips URLs that already have a valid cache entry, so calling
/// it on every app launch is safe and cheap.
class SVGAPrecacheManager {
  static SVGAPrecacheManager? _instance;
  static SVGAPrecacheManager get shared =>
      _instance ??= SVGAPrecacheManager._();

  SVGAPrecacheManager._();

  /// Sources currently being fetched across all in-flight batches.
  /// Used to deduplicate work when overlapping batches request the same URL.
  final Set<String> _inFlight = <String>{};

  int _activeTasks = 0;
  int _activeBatches = 0;
  bool _cancelRequested = false;

  /// Number of precache fetches currently running.
  int get activeTasks => _activeTasks;

  /// Whether any precache batch is currently running.
  bool get isRunning => _activeBatches > 0;

  /// Pre-cache a list of remote SVGA [urls] silently in the background.
  ///
  /// Returns a [Future] that completes with a [SVGAPrecacheResult] once every
  /// entry has been processed. Awaiting the future is optional; callers can
  /// fire-and-forget.
  ///
  /// * [delay] — wait this long before starting, e.g. to avoid contending with
  ///   startup network traffic. `null` or [Duration.zero] starts immediately.
  /// * [concurrency] — maximum parallel downloads (default `3`). Clamped to
  ///   `[1, urls.length]`.
  /// * [skipIfCached] — when `true` (default), URLs that already have a valid
  ///   cache entry are skipped without any network I/O.
  /// * [timeout] — optional per-request timeout. Timed-out requests are
  ///   counted as failures but never throw.
  /// * [onProgress] — optional per-entry progress callback.
  Future<SVGAPrecacheResult> precache(
    List<String> urls, {
    Duration? delay,
    int concurrency = 3,
    bool skipIfCached = true,
    Duration? timeout,
    SVGAPrecacheProgress? onProgress,
  }) {
    return _run(
      sources: urls,
      isAsset: false,
      delay: delay,
      concurrency: concurrency,
      skipIfCached: skipIfCached,
      timeout: timeout,
      onProgress: onProgress,
    );
  }

  /// Pre-cache a list of bundled asset SVGA [paths] silently in the
  /// background. Behaves like [precache] but reads through
  /// [rootBundle].
  Future<SVGAPrecacheResult> precacheAssets(
    List<String> paths, {
    Duration? delay,
    int concurrency = 3,
    bool skipIfCached = true,
    SVGAPrecacheProgress? onProgress,
  }) {
    return _run(
      sources: paths,
      isAsset: true,
      delay: delay,
      concurrency: concurrency,
      skipIfCached: skipIfCached,
      timeout: null,
      onProgress: onProgress,
    );
  }

  /// Request cancellation of any in-flight precache batches.
  ///
  /// Already-started downloads finish, but no new ones are picked up.
  void cancel() {
    if (_activeBatches > 0) {
      _cancelRequested = true;
    }
  }

  Future<SVGAPrecacheResult> _run({
    required List<String> sources,
    required bool isAsset,
    required Duration? delay,
    required int concurrency,
    required bool skipIfCached,
    required Duration? timeout,
    required SVGAPrecacheProgress? onProgress,
  }) async {
    final total = sources.length;
    if (total == 0) {
      return const SVGAPrecacheResult(
        total: 0,
        completed: 0,
        cacheHits: 0,
        fetched: 0,
        failed: 0,
        cancelled: false,
      );
    }

    if (delay != null && delay > Duration.zero) {
      await Future.delayed(delay);
    }

    _activeBatches++;
    // Reset the cancel flag only on the first batch; concurrent callers share
    // the same cancel signal until all batches drain.
    if (_activeBatches == 1) _cancelRequested = false;

    final queue = List<String>.from(sources);
    int completed = 0;
    int hits = 0;
    int fetched = 0;
    int failed = 0;

    Future<void> worker() async {
      while (true) {
        if (_cancelRequested) return;
        if (queue.isEmpty) return;
        final source = queue.removeAt(0);
        final cacheKey = isAsset ? 'assets:$source' : source;

        // If another batch is already fetching this exact source, wait for its
        // cache entry rather than downloading twice.
        if (_inFlight.contains(cacheKey)) {
          completed++;
          onProgress?.call(completed, total, source, true);
          continue;
        }

        _inFlight.add(cacheKey);
        _activeTasks++;
        bool success = false;
        try {
          if (skipIfCached && await SVGACache.shared.contains(cacheKey)) {
            hits++;
            success = true;
          } else if (isAsset) {
            final data = await rootBundle.load(source);
            await SVGACache.shared.putRawBytes(
              cacheKey,
              data.buffer.asUint8List(),
            );
            fetched++;
            success = true;
          } else {
            final uri = Uri.parse(source);
            final request = http.get(uri);
            final response = timeout != null
                ? await request.timeout(timeout)
                : await request;
            if (response.statusCode >= 200 && response.statusCode < 300) {
              await SVGACache.shared.putRawBytes(
                cacheKey,
                Uint8List.fromList(response.bodyBytes),
              );
              fetched++;
              success = true;
            } else {
              failed++;
            }
          }
        } catch (_) {
          // Network errors, asset misses, disk errors — all swallowed so
          // precache stays silent and one bad URL never blocks the rest.
          failed++;
        } finally {
          _inFlight.remove(cacheKey);
          _activeTasks--;
        }

        completed++;
        onProgress?.call(completed, total, source, success);
      }
    }

    final workerCount = concurrency < 1
        ? 1
        : (concurrency > total ? total : concurrency);
    try {
      await Future.wait(List.generate(workerCount, (_) => worker()));
    } finally {
      _activeBatches--;
      if (_activeBatches == 0) _cancelRequested = false;
    }

    return SVGAPrecacheResult(
      total: total,
      completed: completed,
      cacheHits: hits,
      fetched: fetched,
      failed: failed,
      cancelled: _cancelRequested && completed < total,
    );
  }
}
