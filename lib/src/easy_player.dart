part of 'player.dart';

class SVGAEasyPlayer extends StatefulWidget {
  final String? resUrl;
  final String? assetsName;
  final BoxFit fit;

  /// Number of times to repeat the animation.
  /// - `null` (default): Repeat infinitely
  /// - `0`: Play once without repeating
  /// - `n > 0`: Repeat n times (total playback = n + 1 times)
  final int? loops;

  /// Callback function called when the animation finishes playing.
  /// - For infinite loops (`loops == null`), this is never called
  /// - For play once (`loops == 0`), called after single playback
  /// - For repeat n times (`loops > 0`), called after all repetitions complete
  final VoidCallback? onFinished;

  /// Whether to use caching for this animation.
  /// - `true` (default): Use cache if available, store to cache after loading
  /// - `false`: Bypass cache completely, always load fresh
  /// 
  /// Note: This only affects this specific widget instance. 
  /// Global cache settings via `SVGACache.shared` still apply.
  final bool useCache;

  /// Clear this animation from cache when the widget is disposed.
  /// - `false` (default): Keep cached data for future use
  /// - `true`: Remove from cache when widget is disposed
  /// 
  /// Useful for one-time animations that won't be reused.
  final bool clearCacheOnDispose;

  const SVGAEasyPlayer({
    super.key,
    this.resUrl,
    this.assetsName,
    this.fit = BoxFit.contain,
    this.loops,
    this.onFinished,
    this.useCache = true,
    this.clearCacheOnDispose = false,
  });

  @override
  State<StatefulWidget> createState() {
    return _SVGAEasyPlayerState();
  }
}

class _SVGAEasyPlayerState extends State<SVGAEasyPlayer>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? animationController;
  int _currentLoopCount = 0;

  @override
  void initState() {
    super.initState();
    animationController = SVGAAnimationController(vsync: this);
    animationController!.addStatusListener(_onAnimationStatus);
    _tryDecodeSvga();
  }

  @override
  void didUpdateWidget(covariant SVGAEasyPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resUrl != widget.resUrl ||
        oldWidget.assetsName != widget.assetsName) {
      _tryDecodeSvga();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (animationController == null) {
      return Container();
    }
    return SVGAImage(
      animationController!,
      fit: widget.fit,
    );
  }

  @override
  void dispose() {
    animationController?.removeStatusListener(_onAnimationStatus);
    animationController?.dispose();
    animationController = null;
    
    // Clear cache if requested
    if (widget.clearCacheOnDispose) {
      _clearCacheForCurrentSource();
    }
    
    super.dispose();
  }

  /// Clear cache for the current animation source
  Future<void> _clearCacheForCurrentSource() async {
    try {
      if (widget.resUrl != null) {
        await SVGACache.shared.remove(widget.resUrl!);
      } else if (widget.assetsName != null) {
        await SVGACache.shared.remove('assets:${widget.assetsName!}');
      }
    } catch (e) {
      // Silently fail - cache clearing is not critical
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _currentLoopCount++;
      
      // Check if we should continue looping
      final shouldContinue = widget.loops == null || _currentLoopCount <= widget.loops!;
      
      if (shouldContinue) {
        // Continue animation
        if (mounted && animationController != null) {
          animationController!.forward(from: 0.0);
        }
      } else {
        // Animation finished
        if (widget.onFinished != null) {
          widget.onFinished!();
        }
      }
    }
  }

  void _tryDecodeSvga() {
    Future<MovieEntity> decode;
    if (widget.resUrl != null) {
      decode = _loadFromURL(widget.resUrl!);
    } else if (widget.assetsName != null) {
      decode = _loadFromAssets(widget.assetsName!);
    } else {
      return;
    }

    decode.then((videoItem) {
      if (mounted && animationController != null) {
        _currentLoopCount = 0; // Reset loop counter
        animationController!.videoItem = videoItem;
        
        // Start animation based on loops setting
        if (widget.loops == null) {
          // Infinite repeat (default behavior)
          animationController!.repeat();
        } else {
          // Play once or repeat n times
          animationController!.forward(from: 0.0);
        }
      } else {
        videoItem.dispose();
      }
    }).catchError(
      (e, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: e,
            stack: stack,
            library: 'SVGAEasyPlayer',
            context: ErrorDescription('during _tryDecodeSvga'),
            informationCollector: () => [
              if (widget.resUrl != null)
                StringProperty('resUrl', widget.resUrl),
              if (widget.assetsName != null)
                StringProperty('assetsName', widget.assetsName),
            ],
          ),
        );
      },
    );
  }

  /// Load SVGA from URL with cache control
  Future<MovieEntity> _loadFromURL(String url) async {
    if (!widget.useCache) {
      // Bypass cache - load directly
      final wasCacheEnabled = SVGACache.shared.isEnabled;
      SVGACache.shared.setEnabled(false);
      try {
        return await SVGAParser.shared.decodeFromURL(url);
      } finally {
        SVGACache.shared.setEnabled(wasCacheEnabled);
      }
    }
    // Use normal caching behavior
    return SVGAParser.shared.decodeFromURL(url);
  }

  /// Load SVGA from assets with cache control
  Future<MovieEntity> _loadFromAssets(String path) async {
    if (!widget.useCache) {
      // Bypass cache - load directly
      final wasCacheEnabled = SVGACache.shared.isEnabled;
      SVGACache.shared.setEnabled(false);
      try {
        return await SVGAParser.shared.decodeFromAssets(path);
      } finally {
        SVGACache.shared.setEnabled(wasCacheEnabled);
      }
    }
    // Use normal caching behavior
    return SVGAParser.shared.decodeFromAssets(path);
  }
}
