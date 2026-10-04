import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persistent on-disk cache of downloaded SVGA files.
///
/// Entries are stored as the raw downloaded bytes, keyed by URL. The cache
/// keeps an index in memory, so lookups and size checks never scan the
/// directory, and it evicts the least recently used files once the size
/// limit is exceeded.
///
/// Every method is safe to call at any time: a missing or unwritable cache
/// directory, a file deleted by the OS, or an unsupported platform (web)
/// simply behaves like an empty cache.
class SVGACache {
  SVGACache._();

  static SVGACache? _instance;
  static SVGACache get shared => _instance ??= SVGACache._();

  static const String _extension = '.svga';
  static const Duration _touchInterval = Duration(hours: 1);

  bool _enabled = true;
  int _maxCacheSize = 100 * 1024 * 1024;
  Duration _maxAge = const Duration(days: 7);

  Directory? _directoryOverride;
  Future<_Store?>? _opening;
  int _tempCounter = 0;

  /// Whether caching is enabled. Defaults to `true`.
  bool get isEnabled => _enabled;

  /// Maximum total size of the cache in bytes. Defaults to 100 MB.
  int get maxCacheSize => _maxCacheSize;

  /// How long a downloaded file is trusted before it is fetched again.
  /// Defaults to 7 days.
  Duration get maxAge => _maxAge;

  /// Turns the cache on or off. While off, nothing is read or written;
  /// existing files stay on disk and can still be removed with [clear].
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Sets the size limit and trims the cache down to it.
  void setMaxCacheSize(int sizeInBytes) {
    _maxCacheSize = sizeInBytes < 0 ? 0 : sizeInBytes;
    _open().then((store) => store == null ? null : _trim(store));
  }

  /// Sets how long a downloaded file is trusted.
  void setMaxAge(Duration duration) {
    _maxAge = duration;
  }

  /// Uses [directory] instead of the platform's temporary directory.
  @visibleForTesting
  void debugUseDirectory(Directory? directory) {
    _directoryOverride = directory;
    _opening = null;
  }

  /// Whether a usable entry exists for [source] (normally a URL).
  Future<bool> contains(String source) async {
    if (!_enabled) return false;
    final store = await _open();
    if (store == null) return false;
    final entry = store.entries[_fileName(source)];
    return entry != null && !_isExpired(entry);
  }

  /// Returns the cached bytes for [source], or `null` if there is no usable
  /// entry.
  Future<Uint8List?> getRawBytes(String source) async {
    if (!_enabled) return null;
    final store = await _open();
    if (store == null) return null;

    final name = _fileName(source);
    final entry = store.entries[name];
    if (entry == null) return null;
    if (_isExpired(entry)) {
      await _delete(store, name);
      return null;
    }

    final file = store.file(name);
    try {
      final bytes = await file.readAsBytes();
      final now = DateTime.now();
      if (now.difference(entry.used) > _touchInterval) {
        // Persist "recently used" so eviction order survives a restart.
        // Throttled so a hot entry does not cost a write on every read.
        file.setLastAccessed(now).then<void>((_) {}, onError: (_) {});
      }
      entry.used = now;
      return bytes;
    } on FileSystemException {
      // The OS may clear temporary files behind our back.
      store.forget(name);
      return null;
    }
  }

  /// Stores [bytes] for [source].
  ///
  /// The file is written under a temporary name and renamed into place, so
  /// an interrupted write never leaves a half-written entry behind.
  Future<void> putRawBytes(String source, Uint8List bytes) async {
    if (!_enabled || bytes.isEmpty || bytes.length > _maxCacheSize) return;
    final store = await _open();
    if (store == null) return;

    final name = _fileName(source);
    final temp = File('${store.directory.path}/$name.${_tempCounter++}.tmp');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(store.file(name).path);
    } on FileSystemException {
      temp.delete().then<void>((_) {}, onError: (_) {});
      return;
    }
    final now = DateTime.now();
    store.remember(name, _Entry(bytes.length, now, now));
    await _trim(store, keep: name);
  }

  /// Removes the entry for [source], if any.
  Future<void> remove(String source) async {
    final store = await _open();
    if (store == null) return;
    await _delete(store, _fileName(source));
  }

  /// Removes every cached file.
  Future<void> clear() async {
    final store = await _open();
    if (store == null) return;
    for (final name in store.entries.keys.toList()) {
      await _delete(store, name);
    }
  }

  /// Total size of the cached files in bytes.
  Future<int> getCacheSize() async {
    final store = await _open();
    return store?.totalSize ?? 0;
  }

  /// A snapshot of the cache state.
  ///
  /// Keys: `enabled`, `available`, `size`, `maxSize`, `fileCount`, `maxAge`
  /// (in whole days).
  Future<Map<String, dynamic>> getStats() async {
    final store = await _open();
    return {
      'enabled': _enabled,
      'available': store != null,
      'size': store?.totalSize ?? 0,
      'maxSize': _maxCacheSize,
      'fileCount': store?.entries.length ?? 0,
      'maxAge': _maxAge.inDays,
    };
  }

  String _fileName(String source) =>
      '${md5.convert(utf8.encode(source))}$_extension';

  bool _isExpired(_Entry entry) =>
      DateTime.now().difference(entry.written) > _maxAge;

  Future<_Store?> _open() {
    final opening = _opening;
    if (opening != null) return opening;
    final attempt = _Store.open(_directoryOverride);
    _opening = attempt;
    // A failed open is retried on the next call instead of being remembered.
    attempt.then((store) {
      if (store == null && identical(_opening, attempt)) _opening = null;
    });
    return attempt;
  }

  Future<void> _delete(_Store store, String name) async {
    store.forget(name);
    try {
      await store.file(name).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  /// Drops expired entries, then the least recently used ones until the
  /// cache fits. [keep] is never evicted for size.
  Future<void> _trim(_Store store, {String? keep}) async {
    for (final name in store.entries.keys.toList()) {
      final entry = store.entries[name];
      if (entry != null && _isExpired(entry)) await _delete(store, name);
    }
    if (store.totalSize <= _maxCacheSize) return;

    final byAge = store.entries.entries.toList()
      ..sort((a, b) => a.value.used.compareTo(b.value.used));
    for (final candidate in byAge) {
      if (store.totalSize <= _maxCacheSize) break;
      if (candidate.key == keep) continue;
      await _delete(store, candidate.key);
    }
  }
}

class _Entry {
  _Entry(this.size, this.written, this.used);

  final int size;
  final DateTime written;
  DateTime used;
}

/// The cache directory plus an in-memory index of what it holds.
class _Store {
  _Store(this.directory);

  final Directory directory;
  final Map<String, _Entry> entries = {};
  int totalSize = 0;

  File file(String name) => File('${directory.path}/$name');

  void remember(String name, _Entry entry) {
    forget(name);
    entries[name] = entry;
    totalSize += entry.size;
  }

  void forget(String name) {
    final previous = entries.remove(name);
    if (previous != null) totalSize -= previous.size;
  }

  static Future<_Store?> open(Directory? override) async {
    if (kIsWeb) return null;
    try {
      final directory =
          override ??
          Directory('${(await getTemporaryDirectory()).path}/svga_cache');
      await directory.create(recursive: true);
      final store = _Store(directory);
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (name.endsWith(SVGACache._extension)) {
          final stat = await entity.stat();
          final used = stat.accessed.isAfter(stat.modified)
              ? stat.accessed
              : stat.modified;
          store.remember(name, _Entry(stat.size, stat.modified, used));
        } else if (name.endsWith('.tmp')) {
          // Left over from a write that was interrupted.
          entity.delete().then<void>((_) {}, onError: (_) {});
        }
      }
      return store;
    } catch (_) {
      return null;
    }
  }
}
