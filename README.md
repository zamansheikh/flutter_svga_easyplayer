# flutter_svga_easyplayer

[![pub version](https://img.shields.io/pub/v/flutter_svga_easyplayer.svg)](https://pub.dev/packages/flutter_svga_easyplayer)
[![pub points](https://img.shields.io/pub/points/flutter_svga_easyplayer)](https://pub.dev/packages/flutter_svga_easyplayer/score)
[![license](https://img.shields.io/github/license/zamansheikh/flutter_svga_easyplayer)](LICENSE)

Play SVGA animations in Flutter with one widget. Caching, precaching, sound,
loading states and typed errors are built in.

![Ten gift animations playing in a grid](https://raw.githubusercontent.com/zamansheikh/flutter_svga_easyplayer/main/doc/preview.gif)

## Features

- **One widget.** `SVGAEasyPlayer` downloads, caches, decodes, plays and cleans up.
- **Nothing fails silently.** Every failure is a typed `SVGAException`, with a placeholder and an error widget to show while loading or when it fails.
- **Safe caching.** Files are stored only after they decode, written atomically and verified by checksum. A bad entry replaces itself.
- **Shared decoding.** Players showing the same animation decode it once and share the bitmaps.
- **Smooth.** Large files decode off the UI thread, and the canvas repaints only when the frame changes.
- **Light.** The SVGA format is read by the package itself; no protobuf runtime.

## Install

```yaml
dependencies:
  flutter_svga_easyplayer: ^0.1.0
```

```dart
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
```

Animations with sound use [`audioplayers`](https://pub.dev/packages/audioplayers);
follow its platform setup if you need sound.

## Usage

```dart
// From the network
const SVGAEasyPlayer(resUrl: 'https://cdn.example.com/gift.svga')

// From an asset
const SVGAEasyPlayer(assetsName: 'assets/gift.svga')
```

A fuller example:

```dart
SVGAEasyPlayer(
  resUrl: url,
  loops: 0, // play once
  fit: BoxFit.cover,
  volume: 0.5,
  placeholder: const CircularProgressIndicator(),
  errorBuilder: (context, error) => const Icon(Icons.broken_image),
  onFinished: () => Navigator.pop(context),
)
```

| Option | Default | What it does |
|---|---|---|
| `resUrl` / `assetsName` | — | Where the animation comes from. |
| `loops` | `null` | `null` repeats forever, `0` plays once, `n` plays `n + 1` times. |
| `onFinished` | — | Called when a finite playback ends. |
| `fit` | `BoxFit.contain` | How the animation fills its box. |
| `volume` / `isMute` | `1.0` / `false` | Sound level, and mute without losing it. |
| `placeholder` | nothing | Shown while loading. |
| `errorBuilder` / `onError` | nothing | Shown, or called, when loading fails. |
| `onLoaded` | — | Called with the decoded animation before it plays. |
| `clearsAfterStop` | `true` | Blank the canvas when playback ends; `false` keeps the last frame. |
| `useCache` | `true` | `false` loads fresh and stores nothing, for this widget only. |
| `clearCacheOnDispose` | `false` | Delete the cached file when the widget is removed. |
| `headers` / `timeout` | — / 30 s | For the download. |

## Errors

Every failure extends `SVGAException` and carries `message`, `source` and `cause`.

| Type | When |
|---|---|
| `SVGANetworkException` | The request failed or the server answered with a non-2xx `statusCode`. |
| `SVGATimeoutException` | The download took longer than `timeout`. |
| `SVGAFormatException` | Not a complete SVGA 2.x file: an error page, a cut-off download, an SVGA 1.x archive. |
| `SVGAAssetException` | The asset is not in the bundle. |

```dart
errorBuilder: (context, error) => switch (error) {
  SVGANetworkException(statusCode: 404) => const Text('Not found'),
  SVGATimeoutException() => const Text('Slow connection'),
  _ => const Icon(Icons.broken_image),
},
```

## Caching

Both caches work without configuration.

```dart
// Downloaded files, on disk
SVGACache.shared
  ..setMaxCacheSize(200 * 1024 * 1024)   // default 100 MB
  ..setMaxAge(const Duration(days: 30)); // default 7 days
await SVGACache.shared.clear();

// Decoded animations, in memory
SVGAMemoryCache.shared.maxIdleBytes = 64 * 1024 * 1024; // default 32 MB
SVGAMemoryCache.shared.clear();
```

Over the disk limit, the least recently used files are removed first. Assets
are read from the app bundle and are not copied to disk.

## Precaching

Download animations ahead of time so the first playback starts instantly.

```dart
final result = await SVGAPrecacheManager.shared.precache(
  ['https://cdn.example.com/a.svga', 'https://cdn.example.com/b.svga'],
  delay: const Duration(seconds: 2),
  onProgress: (done, total, url, ok) {},
);

SVGAPrecacheManager.shared.cancel();
```

It never throws, skips files that are already cached, and stores a download
only after verifying it. Calling it on every launch is safe.

## Full control

`SVGAAnimationController` is a regular `AnimationController`.

```dart
final controller = SVGAAnimationController(vsync: this);

final movie = await SVGAParser.shared.decodeFromURL(url); // or decodeFromAssets
controller
  ..videoItem = movie
  ..repeat();

// in build:
SVGAImage(controller)
```

Replace parts of an animation at runtime by layer name:

```dart
movie.dynamicItem
  ..setText(textPainter, 'banner')
  ..setHidden(true, 'watermark')
  ..setDynamicDrawer((canvas, frame) {}, 'badge');
await movie.dynamicItem.setImageWithUrl(avatarUrl, 'avatar');
```

Players that share a cached animation also share its `dynamicItem`; pass
`useCache: false` to `SVGAEasyPlayer` when one widget needs its own.

## Performance

Compared with 0.0.7 on the gift animations in the example app, using
`test/benchmark/render_bench.dart`. Output was compared pixel for pixel on
173 frames from 15 files and is identical.

| Animation | Decode | Paint one frame |
|---|---|---|
| `kiss` (54 KB, 10 layers) | 0.8 → 0.6 ms | 40 → 33 µs |
| `corgi-cloud` (118 KB, 39 layers) | 2.2 → 1.5 ms | 64 → 52 µs |
| `bunny-birthday-cake` (240 KB, 100 layers) | 5.7 → 3.8 ms | 97 → 68 µs |
| `blue-rose-heart` (132 KB, 102 layers) | 13.5 → 2.7 ms | 136 → 112 µs |
| `heart-jar` (165 KB, 609 layers) | 18.3 → 3.7 ms | 283 → 51 µs |

Measured in the Flutter test environment on one machine, so read them as
relative numbers.

## Platforms

Android, iOS, macOS, Windows and Linux. Web is experimental: no disk cache,
and decoding runs on the main thread.

SVGA 2.x files are supported. Matte layers are not rendered.

## Migrating from 0.0.x

Widget code keeps working. Three things changed:

- `MovieEntity` is a plain Dart class, not a protobuf message. `params`,
  `sprites`, `audios`, `dynamicItem`, `autorelease` and `dispose()` are the same.
- Load failures are `SVGAException`s instead of raw HTTP or zlib errors.
- Assets are no longer copied into the disk cache, so `precacheAssets` only
  checks that they exist.

## License

[MIT](LICENSE)
