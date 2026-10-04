import 'package:meta/meta.dart';

import '../model.dart';

/// Keeps decoded animations in memory so that several widgets showing the
/// same file share one set of bitmaps, and so that reopening a screen does
/// not decode the file again.
///
/// An animation stays alive while at least one `SVGAEasyPlayer` is showing
/// it. Once the last one goes away it becomes *idle* and is kept until the
/// idle animations together exceed [maxIdleBytes], at which point the least
/// recently used ones are disposed.
class SVGAMemoryCache {
  SVGAMemoryCache._();

  static final SVGAMemoryCache shared = SVGAMemoryCache._();

  // Insertion order doubles as recency: a slot is re-inserted when released.
  final Map<String, _Slot> _slots = {};
  int _maxIdleBytes = 32 * 1024 * 1024;

  /// Memory budget, in bytes of decoded bitmaps, for animations nobody is
  /// currently showing. Defaults to 32 MB. Set to `0` to free an animation
  /// as soon as its last player is disposed.
  int get maxIdleBytes => _maxIdleBytes;
  set maxIdleBytes(int value) {
    _maxIdleBytes = value < 0 ? 0 : value;
    _trim();
  }

  /// Bytes of decoded bitmaps held for animations nobody is showing.
  int get idleBytes {
    var total = 0;
    for (final slot in _slots.values) {
      if (slot.isIdle) total += slot.bytes;
    }
    return total;
  }

  /// Number of animations currently held, in use or idle.
  int get length => _slots.length;

  /// Disposes every idle animation. Animations on screen are untouched.
  void clear() {
    _slots.removeWhere((_, slot) {
      if (!slot.isIdle) return false;
      slot.movie?.dispose();
      return true;
    });
  }

  /// Returns the animation for [key], calling [load] only if no other
  /// caller has already loaded or started loading it.
  ///
  /// Every successful call must be balanced by one [release]. A call whose
  /// future fails must not be released.
  @internal
  Future<MovieEntity> acquire(String key, Future<MovieEntity> Function() load) {
    var slot = _slots[key];
    if (slot == null) {
      final created = _Slot();
      slot = created;
      _slots[key] = created;
      created.future = load().then(
        (movie) {
          movie.autorelease = false;
          created.movie = movie;
          created.bytes = movie.bitmapBytes;
          if (!identical(_slots[key], created)) {
            // Dropped while loading and nobody is waiting for it any more.
            if (created.users == 0) movie.dispose();
          } else if (created.users == 0) {
            _trim();
          }
          return movie;
        },
        onError: (Object error, StackTrace stack) {
          if (identical(_slots[key], created)) _slots.remove(key);
          Error.throwWithStackTrace(error, stack);
        },
      );
    }
    slot.users++;
    return slot.future;
  }

  @internal
  void release(String key, MovieEntity movie) {
    final slot = _slots[key];
    if (slot == null || !identical(slot.movie, movie)) return;
    if (slot.users > 0) slot.users--;
    if (slot.users == 0) {
      _slots.remove(key);
      _slots[key] = slot;
      _trim();
    }
  }

  void _trim() {
    // A zero budget means "keep nothing idle", including animations whose
    // bitmaps add up to no bytes at all.
    final keepNothing = _maxIdleBytes == 0;
    var idle = idleBytes;
    if (!keepNothing && idle <= _maxIdleBytes) return;
    for (final key in _slots.keys.toList()) {
      if (!keepNothing && idle <= _maxIdleBytes) break;
      final slot = _slots[key]!;
      if (!slot.isIdle) continue;
      idle -= slot.bytes;
      slot.movie?.dispose();
      _slots.remove(key);
    }
  }
}

class _Slot {
  late final Future<MovieEntity> future;
  MovieEntity? movie;
  int users = 0;
  int bytes = 0;

  bool get isIdle => users == 0 && movie != null;
}
