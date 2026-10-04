<h1 align="center">flutter_svga_easyplayer</h1>

<p align="center">
  <b>SVGA animations in Flutter, in one line.</b><br>
  Gifts, entry effects, stickers and splash animations that just play,
  with caching, sound and error handling already done for you.
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_svga_easyplayer"><img src="https://img.shields.io/pub/v/flutter_svga_easyplayer.svg" alt="pub version"></a>
  <a href="https://pub.dev/packages/flutter_svga_easyplayer/score"><img src="https://img.shields.io/pub/points/flutter_svga_easyplayer" alt="pub points"></a>
  <a href="https://pub.dev/packages/flutter_svga_easyplayer/score"><img src="https://img.shields.io/pub/likes/flutter_svga_easyplayer" alt="pub likes"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/zamansheikh/flutter_svga_easyplayer" alt="license"></a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/zamansheikh/flutter_svga_easyplayer/main/doc/preview.gif" alt="Ten gift and entry animations playing at once" width="720">
</p>

```dart
SVGAEasyPlayer.network('https://cdn.example.com/gift.svga')
```

That one line downloads the file, caches it, decodes it, plays it with its
sound, and frees everything when the widget goes away.

## Why developers pick it

- **It is one line.** No controllers, no `initState`, no `dispose`. Add the widget and it plays.
- **It stays smooth.** Big animations decode on a background thread, and the screen is redrawn only when the frame actually changes. On the same files it decodes up to 5× faster and paints up to 5.5× faster than version 0.0.7.
- **It loads once.** Files are saved to disk after the first download, and ten widgets showing the same gift share a single decoded copy in memory.
- **It never fails silently.** Show a placeholder while loading and a fallback on error. Every failure has a clear type, so a 404 and a slow connection are easy to tell apart.
- **It cannot be poisoned by a bad download.** A broken or cut-off file is detected, thrown away and fetched again.
- **It is light.** The SVGA format is read by the package itself, with no protobuf runtime to ship.

## Install

```yaml
dependencies:
  flutter_svga_easyplayer: ^0.2.0
```

```dart
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
```

Animations with sound use [`audioplayers`](https://pub.dev/packages/audioplayers);
follow its platform setup if you need sound.

## Quick start

```dart
SVGAEasyPlayer.network('https://cdn.example.com/gift.svga') // from a URL
SVGAEasyPlayer.asset('assets/gift.svga')                    // from an asset
```

How long it plays depends on what you add:

| You write | What happens |
|---|---|
| `SVGAEasyPlayer.network(url)` | Repeats forever |
| `SVGAEasyPlayer.network(url, onFinished: close)` | Plays once, then calls `close` |
| `SVGAEasyPlayer.network(url, playCount: 3)` | Plays three times, then stops |
| `SVGAEasyPlayer.network(url, playCount: 3, onFinished: close)` | Plays three times, then calls `close` |

When it stops, the animation disappears. Add `keepLastFrame: true` to leave
the last frame on screen.

A typical gift effect, with a loading spinner and a fallback:

```dart
SVGAEasyPlayer.network(
  gift.url,
  placeholder: const CircularProgressIndicator(),
  errorBuilder: (context, error) => const Icon(Icons.broken_image),
  onFinished: () => Navigator.pop(context),
)
```

Want to see it running? The [example app](example) is a gift gallery:

```sh
cd example && flutter run
```

## Options

**Playback**

| Option | What it does |
|---|---|
| `onFinished` | Called when the animation finishes. With this set, it plays once instead of repeating. |
| `playCount` | How many times to play, when you want more than once: `3` plays three times. |
| `keepLastFrame` | `true` keeps the last frame on screen when finished. By default the animation disappears. |
| `fit` | How the animation fills its box. Default `BoxFit.contain`. |

**Sound**

| Option | What it does |
|---|---|
| `volume` | Loudness from `0.0` to `1.0`. Default `1.0`. |
| `muted` | `true` turns the sound off. |

**Loading and errors**

| Option | What it does |
|---|---|
| `placeholder` | Widget shown while the animation loads. |
| `errorBuilder` | Widget shown if loading fails. |
| `onLoaded` | Called when the animation is ready, just before it plays. |
| `onError` | Called with the error if loading fails. |

**Network and cache**

| Option | What it does |
|---|---|
| `headers` | Extra HTTP headers, such as an authorization token. |
| `timeout` | How long the download may take. Default 30 seconds. |
| `useCache` | `false` loads the file fresh every time and stores nothing. Default `true`. |
| `clearCacheOnDispose` | `true` deletes the downloaded file when the widget is removed. |

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
`useCache: false` to the player when one widget needs its own.

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

## Migrating

**From 0.1.0.** Old code keeps working, with deprecation hints pointing at
the clearer names:

| Before | Now |
|---|---|
| `SVGAEasyPlayer(resUrl: url)` | `SVGAEasyPlayer.network(url)` |
| `SVGAEasyPlayer(assetsName: path)` | `SVGAEasyPlayer.asset(path)` |
| `loops: 0` | `playCount: 1` |
| `loops: 2` | `playCount: 3` |
| `isMute: true` | `muted: true` |
| `clearsAfterStop: false` | `keepLastFrame: true` |

**From 0.0.x.** In addition:

- `MovieEntity` is a plain Dart class, not a protobuf message. `params`,
  `sprites`, `audios`, `dynamicItem`, `autorelease` and `dispose()` are the same.
- Load failures are `SVGAException`s instead of raw HTTP or zlib errors.
- Assets are no longer copied into the disk cache, so `precacheAssets` only
  checks that they exist.

## License

[MIT](LICENSE)
