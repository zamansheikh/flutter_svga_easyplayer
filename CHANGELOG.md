# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-10-05

The package has been rewritten from the ground up. Rendering is unchanged:
173 frames from 15 files were compared pixel for pixel with 0.0.7 and are
identical.

### Added

- **Typed errors.** Every failure is an `SVGAException`:
  `SVGANetworkException` (with `statusCode`), `SVGATimeoutException`,
  `SVGAFormatException` and `SVGAAssetException`.
- **Loading and error states** on `SVGAEasyPlayer`: `placeholder`,
  `errorBuilder`, `onLoaded` and `onError`.
- **`SVGAMemoryCache`.** Players showing the same source share one decoded
  animation, and it stays warm after the last player is removed.
- **Volume control**: `volume` on `SVGAEasyPlayer` and
  `SVGAAnimationController`, alongside `isMute`.
- `headers`, `timeout`, `filterQuality`, `allowDrawingOverflow` and
  `clearsAfterStop` on `SVGAEasyPlayer`.
- `useCache`, `headers` and `timeout` on `SVGAParser.decodeFromURL`;
  `bundle` and `package` on `decodeFromAssets`.
- `SVGAParser.httpClient`, `SVGAParser.defaultTimeout` (30 s) and
  `SVGAParser.isolateThreshold`.

### Changed

- **Own SVGA reader.** The file format is decoded by the package itself; the
  `protobuf` and `path_drawing` dependencies are gone. `MovieEntity` and its
  parts are now plain Dart classes.
- **Faster.** On the example gifts, decoding is up to 5× faster and
  painting a frame up to 5.5× faster than 0.0.7, and no file is slower (see
  the README). Files of 64 KB or more decode on a background isolate, and
  the canvas repaints only when the frame changes rather than on every
  display refresh.
- **Disk cache rewritten.** Atomic writes, an in-memory index instead of a
  directory scan on every write, and least-recently-used eviction.
- Assets are read straight from the bundle and are no longer copied into
  the disk cache. `precacheAssets` now only validates the assets.
- Sound restarts with each loop and is written to disk when the animation
  loads rather than when it first plays.

### Fixed

- Two animations that used the same audio key for different sounds could
  play each other's sound.
- `SVGAEasyPlayer(useCache: false)` could leave the global cache switched
  off for the whole app.
- `SVGACache.clear()` and `getCacheSize()` did nothing until the cache had
  been read or written once.
- A truncated download could be cached and played as a broken animation;
  files are now verified against their checksum.
- A non-2xx response surfaced as a zlib "Filter error".
- `SVGAPrecacheResult.cancelled` was always `false`, and `cancel()` was
  ignored during the start delay.
- A slow earlier load could overwrite a newer one after the source changed.
- A blank frame could flash between loops.
- Audio players of a replaced animation were never released.
- A missing audio plugin or an undecodable sound no longer breaks playback.

### Removed

- The separate cache, playback and quick-reference guides; the README now
  covers them.
- The old sample animations. The example app is now a gallery of gift
  animations.

### Migration

See "Migrating from 0.0.x" in the README. Typical widget code needs no
changes.

## [0.0.7] - 2026-04-21

### 🩹 Fixes

- **Cache-poisoning hardening**: The parser now caches raw bytes *only
  after* a successful decode, and if a cached entry fails to decode (e.g.
  a previously poisoned entry) it is automatically evicted and re-fetched
  once. This eliminates the recurring
  `Exception caught by SVGAEasyPlayer: Filter error, bad data` log that
  could appear when a CDN momentarily served a non-SVGA payload (HTML
  error page with 200 status, truncated file, redirect, etc.).
- **Precache payload validation**: `SVGAPrecacheManager` verifies the
  zlib magic byte of each downloaded/loaded payload before writing to the
  cache. Bad responses are counted as `failed` and never stored.

### ✅ Compatibility

- Fully backward compatible. No public API changes.

## [0.0.6] - 2026-04-21

### ✨ New Features

- **Silent Precaching (`SVGAPrecacheManager`)**: Pre-fetch a list of SVGA
  URLs or asset paths into the persistent cache at app startup so playback
  starts instantly the first time a user opens a screen that uses them.
  - Fire-and-forget API: `SVGAPrecacheManager.shared.precache([...])`
  - Optional `delay` so precaching does not contend with startup traffic.
  - Configurable `concurrency` (default 3) with per-URL deduplication.
  - Optional per-request `timeout` and per-entry `onProgress` callback.
  - `skipIfCached` avoids re-downloading valid cache entries.
  - `cancel()` stops further work without interrupting the player.
- **`SVGACache.contains(source)`**: Cheap async lookup to check whether a
  valid (non-expired) cache entry exists for a given URL or `assets:` key.

### 🛠 Improvements

- Bumped `archive` to `^4.0.9`, `audioplayers` to `^6.6.0`, and `lints` to
  `^6.1.0` in `pubspec.yaml`.

### ✅ Compatibility

- Fully backward compatible. Existing `SVGAEasyPlayer`, `SVGAParser`, and
  `SVGACache` APIs behave exactly as before — precaching just populates the
  same cache the parser already reads from on playback.

## [0.0.5] - 2025-12-3

### 🛠 Version Bump

- Bumped version to 0.0.5
- Maintenance release, no breaking changes
- Updated dependencies in `pubspec.yaml`

## [0.0.4] - 2025-12-03

### 🛠 Fixes & Improvements

- **Protobuf Compatibility**: Fixed compatibility issues with `protobuf` ^6.0.0.
- **Audio Control**: Added `isMute` property to `SVGAEasyPlayer` and `SVGAAnimationController` to allow muting audio.
- **Lint Fixes**: Resolved analysis warnings in generated files.

## [0.0.3] - 2025-11-23

### 🛠 Version Bump

- Bumped version to 0.0.3
- Maintenance release, no breaking changes
- Updated dependencies in `pubspec.yaml`

## [0.0.2] - 2025-11-10

### 🛠 Version Bump

- Bumped version to 0.0.2
- Maintenance release, no breaking changes
- Updated dependencies in `pubspec.yaml`

## [0.0.1] - 2025-11-09

### 🎉 Initial Release

This is the initial release of `flutter_svga_easyplayer` - a powerful Flutter package for rendering SVGA animations with advanced features.

### ✨ Features

#### SVGAEasyPlayer Widget

- **Simple API**: Load and play SVGA animations with minimal code
- **Multiple Sources**: Support for both assets and network URLs
- **Automatic Resource Management**: Built-in controller and lifecycle handling

#### Playback Control

- **Infinite Loop**: Default continuous playback for loading indicators and backgrounds
- **Play Once**: Single playback with completion callback for splash screens and one-time animations
- **Repeat N Times**: Controlled repetition with completion callback for celebrations and notifications
- **onFinished Callback**: Execute code when animations complete

#### Cache System

- **Global Cache**: Intelligent caching system for better performance
- **Per-Widget Control**: Enable/disable caching on individual players
- **Auto-Cleanup**: Automatic cache removal on widget disposal
- **Storage Management**: Configurable cache size and expiration

#### Advanced Features

- **Dynamic Content**: Replace text, images, and add custom drawings
- **Audio Playback**: Integrated audio support within animations
- **Performance Optimized**: Efficient rendering and memory management
- **Flexible Layout**: BoxFit support for responsive designs

### � Documentation

- Comprehensive README with quick start guide
- Detailed playback modes documentation
- Cache control guide
- Quick reference cheat sheet
- Interactive example applications

### 🎮 Examples

- Playback modes demonstration
- Cache control examples
- Global cache management
- Dynamic content samples

### �️ Technical

- Flutter SDK: >=3.8.1
- Dart SDK: >=3.0.0
- Platform Support: Android, iOS, Desktop, Web
- Dependencies: archive, http, protobuf, audioplayers, path_provider, crypto
