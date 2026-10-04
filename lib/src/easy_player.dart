import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'io/cache.dart';
import 'io/memory_cache.dart';
import 'model.dart';
import 'parser.dart';
import 'player.dart';

/// Builds the widget shown in place of an animation that failed to load.
typedef SVGAErrorWidgetBuilder =
    Widget Function(BuildContext context, Object error);

/// Called when an animation fails to load.
typedef SVGAErrorCallback = void Function(Object error, StackTrace stackTrace);

/// Loads and plays an SVGA animation from a URL or an asset.
///
/// ```dart
/// SVGAEasyPlayer(
///   resUrl: 'https://example.com/gift.svga',
///   loops: 0,
///   placeholder: const CircularProgressIndicator(),
///   errorBuilder: (context, error) => const Icon(Icons.broken_image),
///   onFinished: () => Navigator.pop(context),
/// )
/// ```
///
/// The widget owns everything it needs: it downloads and caches the file,
/// shares the decoded animation with any other player showing the same
/// source, and releases its resources when it is removed from the tree.
class SVGAEasyPlayer extends StatefulWidget {
  const SVGAEasyPlayer({
    super.key,
    this.resUrl,
    this.assetsName,
    this.fit = BoxFit.contain,
    this.loops,
    this.onFinished,
    this.useCache = true,
    this.clearCacheOnDispose = false,
    this.isMute = false,
    this.volume = 1.0,
    this.filterQuality = FilterQuality.low,
    this.allowDrawingOverflow,
    this.clearsAfterStop = true,
    this.placeholder,
    this.errorBuilder,
    this.onLoaded,
    this.onError,
    this.headers,
    this.timeout,
  });

  /// URL of the animation. Takes precedence over [assetsName].
  final String? resUrl;

  /// Asset path of the animation, used when [resUrl] is `null`.
  final String? assetsName;

  /// How the animation is fitted into the available space.
  final BoxFit fit;

  /// How many times to repeat after the first playback.
  ///
  /// * `null` (default): repeat forever.
  /// * `0`: play once.
  /// * `n`: play `n + 1` times in total.
  final int? loops;

  /// Called once when a finite playback ([loops] is not `null`) completes.
  final VoidCallback? onFinished;

  /// Whether to use the disk cache and the shared in-memory cache.
  ///
  /// With `false` the file is downloaded and decoded afresh for this widget
  /// alone, and nothing is stored. Other widgets are not affected.
  final bool useCache;

  /// Whether to delete this animation's cached file when the widget is
  /// disposed. Useful for one-off animations that will not be shown again.
  final bool clearCacheOnDispose;

  /// Silences the animation's sound without changing [volume].
  final bool isMute;

  /// Volume of the animation's sound, from `0.0` to `1.0`.
  final double volume;

  /// Sampling quality used for the animation's bitmaps.
  final FilterQuality filterQuality;

  /// Whether the animation may draw outside the widget's bounds. `null`
  /// (the default) and `true` allow it; `false` clips to the bounds.
  final bool? allowDrawingOverflow;

  /// Whether the canvas is blanked once a finite playback completes. With
  /// `false` the last frame stays visible.
  final bool clearsAfterStop;

  /// Shown while the animation is loading. Defaults to nothing.
  final Widget? placeholder;

  /// Builds what is shown when loading fails. Defaults to nothing.
  final SVGAErrorWidgetBuilder? errorBuilder;

  /// Called when the animation has loaded, just before playback starts.
  final ValueChanged<MovieEntity>? onLoaded;

  /// Called when loading fails. When neither this nor [errorBuilder] is
  /// given, the failure is reported through [FlutterError.reportError] so it
  /// is not silently lost.
  final SVGAErrorCallback? onError;

  /// Extra HTTP headers for [resUrl], for example an authorization token.
  final Map<String, String>? headers;

  /// Download timeout for [resUrl]. Defaults to
  /// [SVGAParser.defaultTimeout].
  final Duration? timeout;

  @override
  State<SVGAEasyPlayer> createState() => _SVGAEasyPlayerState();
}

class _SVGAEasyPlayerState extends State<SVGAEasyPlayer>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _controller;

  // Identifies the newest load, so a slow earlier one cannot overwrite it.
  int _request = 0;

  // Set when the current movie came from the shared memory cache and must be
  // handed back to it rather than disposed.
  String? _sharedKey;
  MovieEntity? _sharedMovie;

  bool _loading = false;
  Object? _error;
  int _completedPlays = 0;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this)
      ..isMute = widget.isMute
      ..volume = widget.volume
      ..addStatusListener(_handleStatus);
    _load();
  }

  @override
  void didUpdateWidget(covariant SVGAEasyPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller
      ..isMute = widget.isMute
      ..volume = widget.volume;
    if (oldWidget.resUrl != widget.resUrl ||
        oldWidget.assetsName != widget.assetsName ||
        oldWidget.useCache != widget.useCache) {
      _load();
    } else if (oldWidget.loops != widget.loops &&
        _controller.videoItem != null) {
      _play();
    }
  }

  @override
  void dispose() {
    _request++;
    _controller.dispose();
    _releaseShared();
    final url = widget.resUrl;
    if (widget.clearCacheOnDispose && url != null) {
      SVGACache.shared.remove(url);
    }
    super.dispose();
  }

  void _load() {
    final request = ++_request;
    _controller.videoItem = null;
    _releaseShared();

    final url = widget.resUrl;
    final asset = widget.assetsName;
    if (url == null && asset == null) {
      _loading = false;
      _error = null;
      return;
    }
    _loading = true;
    _error = null;

    // Looked up without subscribing: a new bundle should not restart an
    // animation that is already playing.
    final bundle = context
        .getInheritedWidgetOfExactType<DefaultAssetBundle>()
        ?.bundle;
    Future<MovieEntity> decode() => url != null
        ? SVGAParser.shared.decodeFromURL(
            url,
            useCache: widget.useCache,
            headers: widget.headers,
            timeout: widget.timeout,
          )
        : SVGAParser.shared.decodeFromAssets(asset!, bundle: bundle);

    final sharedKey = widget.useCache
        ? (url != null ? 'url:$url' : 'asset:$asset')
        : null;
    final loading = sharedKey == null
        ? decode()
        : SVGAMemoryCache.shared.acquire(sharedKey, decode);

    loading.then(
      (movie) {
        if (!mounted || request != _request) {
          // Superseded by a newer source, or the widget is gone.
          if (sharedKey != null) {
            SVGAMemoryCache.shared.release(sharedKey, movie);
          } else {
            movie.dispose();
          }
          return;
        }
        _sharedKey = sharedKey;
        _sharedMovie = sharedKey == null ? null : movie;
        setState(() => _loading = false);
        _controller.videoItem = movie;
        widget.onLoaded?.call(movie);
        _play();
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted || request != _request) return;
        setState(() {
          _loading = false;
          _error = error;
        });
        final onError = widget.onError;
        if (onError != null) {
          onError(error, stack);
        } else if (widget.errorBuilder == null) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'flutter_svga_easyplayer',
              context: ErrorDescription('while loading an SVGA animation'),
              informationCollector: () => [
                if (widget.resUrl != null)
                  StringProperty('resUrl', widget.resUrl),
                if (widget.assetsName != null)
                  StringProperty('assetsName', widget.assetsName),
              ],
            ),
          );
        }
      },
    );
  }

  void _releaseShared() {
    final key = _sharedKey;
    final movie = _sharedMovie;
    _sharedKey = null;
    _sharedMovie = null;
    if (key != null && movie != null) {
      SVGAMemoryCache.shared.release(key, movie);
    }
  }

  void _play() {
    _completedPlays = 0;
    if (widget.loops == null) {
      _controller.repeat();
    } else {
      _controller.forward(from: 0.0);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final loops = widget.loops;
    if (loops == null) return;
    _completedPlays++;
    if (_completedPlays <= loops) {
      _controller.forward(from: 0.0);
      return;
    }
    if (widget.clearsAfterStop) _controller.clear();
    widget.onFinished?.call();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return widget.errorBuilder?.call(context, error) ??
          const SizedBox.shrink();
    }
    if (_loading) return widget.placeholder ?? const SizedBox.shrink();
    return SVGAImage(
      _controller,
      fit: widget.fit,
      filterQuality: widget.filterQuality,
      allowDrawingOverflow: widget.allowDrawingOverflow,
      // The player decides when to blank the canvas, so looping never
      // flashes an empty frame between plays.
      clearsAfterStop: false,
    );
  }
}
