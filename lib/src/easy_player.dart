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

/// Loads and plays an SVGA animation.
///
/// ```dart
/// // Loop forever
/// SVGAEasyPlayer.network('https://example.com/gift.svga')
///
/// // Play once, then leave
/// SVGAEasyPlayer.asset(
///   'assets/gift.svga',
///   onFinished: () => Navigator.pop(context),
/// )
///
/// // Play three times
/// SVGAEasyPlayer.asset('assets/gift.svga', playCount: 3)
/// ```
///
/// The widget owns everything it needs: it downloads and caches the file,
/// shares the decoded animation with any other player showing the same
/// source, and releases its resources when it is removed from the tree.
class SVGAEasyPlayer extends StatefulWidget {
  /// Plays the animation at [url].
  const SVGAEasyPlayer.network(
    String this.url, {
    super.key,
    this.playCount,
    this.onFinished,
    this.keepLastFrame = false,
    this.fit = BoxFit.contain,
    this.volume = 1.0,
    this.muted = false,
    this.placeholder,
    this.errorBuilder,
    this.onLoaded,
    this.onError,
    this.headers,
    this.timeout,
    this.useCache = true,
    this.clearCacheOnDispose = false,
    this.filterQuality = FilterQuality.low,
    this.allowDrawingOverflow,
  }) : asset = null,
       _finishImpliesOnce = true,
       assert(playCount == null || playCount > 0);

  /// Plays the animation bundled at the asset path [asset].
  const SVGAEasyPlayer.asset(
    String this.asset, {
    super.key,
    this.playCount,
    this.onFinished,
    this.keepLastFrame = false,
    this.fit = BoxFit.contain,
    this.volume = 1.0,
    this.muted = false,
    this.placeholder,
    this.errorBuilder,
    this.onLoaded,
    this.onError,
    this.useCache = true,
    this.filterQuality = FilterQuality.low,
    this.allowDrawingOverflow,
  }) : url = null,
       headers = null,
       timeout = null,
       clearCacheOnDispose = false,
       _finishImpliesOnce = true,
       assert(playCount == null || playCount > 0);

  /// The original constructor, kept so existing code keeps working.
  ///
  /// Prefer [SVGAEasyPlayer.network] and [SVGAEasyPlayer.asset]. The older
  /// parameter names map onto the current ones:
  ///
  /// * `resUrl` → the URL passed to [SVGAEasyPlayer.network]
  /// * `assetsName` → the path passed to [SVGAEasyPlayer.asset]
  /// * `loops` → [playCount], which counts plays rather than repeats
  ///   (`loops: 0` is `playCount: 1`)
  /// * `isMute` → [muted]
  /// * `clearsAfterStop: false` → `keepLastFrame: true`
  const SVGAEasyPlayer({
    super.key,
    @Deprecated('Use SVGAEasyPlayer.network(url)') String? resUrl,
    @Deprecated('Use SVGAEasyPlayer.asset(path)') String? assetsName,
    @Deprecated('Use playCount, which is loops + 1') int? loops,
    int? playCount,
    this.onFinished,
    bool keepLastFrame = false,
    @Deprecated('Use keepLastFrame, which is the opposite')
    bool? clearsAfterStop,
    this.fit = BoxFit.contain,
    this.volume = 1.0,
    bool muted = false,
    @Deprecated('Use muted') bool? isMute,
    this.placeholder,
    this.errorBuilder,
    this.onLoaded,
    this.onError,
    this.headers,
    this.timeout,
    this.useCache = true,
    this.clearCacheOnDispose = false,
    this.filterQuality = FilterQuality.low,
    this.allowDrawingOverflow,
  }) : assert(loops == null || playCount == null, 'Pass playCount only'),
       assert(loops == null || loops >= 0),
       assert(playCount == null || playCount > 0),
       url = resUrl,
       asset = assetsName,
       _finishImpliesOnce = false,
       playCount = playCount ?? (loops == null ? null : loops + 1),
       muted = isMute ?? muted,
       keepLastFrame = clearsAfterStop == null
           ? keepLastFrame
           : !clearsAfterStop;

  /// URL of the animation, when it comes from the network.
  final String? url;

  /// Asset path of the animation, when it is bundled with the app.
  final String? asset;

  /// How many times to play the animation: `1` plays once, `3` plays three
  /// times.
  ///
  /// When left out, the animation repeats forever, unless [onFinished] is
  /// given, in which case it plays once.
  final int? playCount;

  /// Called after the last play.
  ///
  /// Giving this makes the animation finite: it plays [playCount] times, or
  /// once if [playCount] is left out.
  final VoidCallback? onFinished;

  // The original constructor repeated forever when `loops` was left out,
  // even with an `onFinished`; it keeps doing so.
  final bool _finishImpliesOnce;

  /// How many plays this widget will make, or `null` for "forever".
  int? get _plays =>
      playCount ?? (_finishImpliesOnce && onFinished != null ? 1 : null);

  /// Whether the last frame stays on screen when playback finishes.
  /// By default the animation disappears.
  final bool keepLastFrame;

  /// How the animation is fitted into the available space.
  final BoxFit fit;

  /// How loud the animation's sound is, from `0.0` to `1.0`.
  final double volume;

  /// Whether the animation's sound is off. [volume] is kept for when it is
  /// turned back on.
  final bool muted;

  /// Shown while the animation is loading. Defaults to nothing.
  final Widget? placeholder;

  /// Builds what is shown when loading fails. Defaults to nothing.
  final SVGAErrorWidgetBuilder? errorBuilder;

  /// Called when the animation has loaded, just before it starts playing.
  final ValueChanged<MovieEntity>? onLoaded;

  /// Called when loading fails. When neither this nor [errorBuilder] is
  /// given, the failure is reported through [FlutterError.reportError] so it
  /// is not silently lost.
  final SVGAErrorCallback? onError;

  /// Extra HTTP headers for the download, for example an authorization
  /// token.
  final Map<String, String>? headers;

  /// How long the download may take. Defaults to
  /// [SVGAParser.defaultTimeout].
  final Duration? timeout;

  /// Whether to use the disk cache and the shared in-memory cache.
  ///
  /// With `false` the file is downloaded and decoded afresh for this widget
  /// alone, and nothing is stored. Other widgets are not affected.
  final bool useCache;

  /// Whether to delete the downloaded file from the disk cache when this
  /// widget is removed. Useful for animations that will not be shown again.
  final bool clearCacheOnDispose;

  /// Sampling quality used for the animation's bitmaps.
  final FilterQuality filterQuality;

  /// Whether the animation may draw outside the widget's bounds. `null`
  /// (the default) and `true` allow it; `false` clips to the bounds.
  final bool? allowDrawingOverflow;

  @Deprecated('Use url')
  String? get resUrl => url;

  @Deprecated('Use asset')
  String? get assetsName => asset;

  @Deprecated('Use playCount, which is loops + 1')
  int? get loops => playCount == null ? null : playCount! - 1;

  @Deprecated('Use muted')
  bool get isMute => muted;

  @Deprecated('Use keepLastFrame, which is the opposite')
  bool get clearsAfterStop => !keepLastFrame;

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
      ..muted = widget.muted
      ..volume = widget.volume
      ..addStatusListener(_handleStatus);
    _load();
  }

  @override
  void didUpdateWidget(covariant SVGAEasyPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller
      ..muted = widget.muted
      ..volume = widget.volume;
    if (oldWidget.url != widget.url ||
        oldWidget.asset != widget.asset ||
        oldWidget.useCache != widget.useCache) {
      _load();
    } else if (oldWidget._plays != widget._plays &&
        _controller.videoItem != null) {
      _play();
    }
  }

  @override
  void dispose() {
    _request++;
    _controller.dispose();
    _releaseShared();
    final url = widget.url;
    if (widget.clearCacheOnDispose && url != null) {
      SVGACache.shared.remove(url);
    }
    super.dispose();
  }

  void _load() {
    final request = ++_request;
    _controller.videoItem = null;
    _releaseShared();

    final url = widget.url;
    final asset = widget.asset;
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
                if (widget.url != null) StringProperty('url', widget.url),
                if (widget.asset != null) StringProperty('asset', widget.asset),
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
    if (widget._plays == null) {
      _controller.repeat();
    } else {
      _controller.forward(from: 0.0);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final playCount = widget._plays;
    if (playCount == null) return;
    _completedPlays++;
    if (_completedPlays < playCount) {
      _controller.forward(from: 0.0);
      return;
    }
    if (!widget.keepLastFrame) _controller.clear();
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
