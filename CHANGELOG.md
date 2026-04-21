# Changelog

All notable changes to this project will be documented in this file.

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
