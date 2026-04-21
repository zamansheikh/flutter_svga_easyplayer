<h1 align="center">flutter_svga_easyplayer</h1>

<p align="center">
  A production-ready SVGA renderer for Flutter with an easy-to-use player,
  intelligent caching, silent background precaching, dynamic content
  overrides, and integrated audio playback.
</p>

<p align="center">
  <a href="https://pub.dev/packages/flutter_svga_easyplayer"><img src="https://img.shields.io/pub/v/flutter_svga_easyplayer.svg" alt="pub version"></a>
  <a href="https://pub.dev/packages/flutter_svga_easyplayer/score"><img src="https://img.shields.io/pub/points/flutter_svga_easyplayer" alt="pub points"></a>
  <a href="https://pub.dev/packages/flutter_svga_easyplayer/score"><img src="https://img.shields.io/pub/likes/flutter_svga_easyplayer" alt="pub likes"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/zamansheikh/flutter_svga_easyplayer" alt="license"></a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/zamansheikh/flutter_svga_easyplayer/master/example.gif" width="300"/>
  <img src="https://raw.githubusercontent.com/zamansheikh/flutter_svga_easyplayer/master/example1.gif" width="300"/>
</p>

---

## Table of contents

- [Highlights](#highlights)
- [Install](#install)
- [Quick start](#quick-start)
- [Loading animations](#loading-animations)
- [Playback modes](#playback-modes)
- [Audio control](#audio-control)
- [Caching](#caching)
- [Background precaching](#background-precaching)
- [Dynamic content](#dynamic-content)
- [Using the controller directly](#using-the-controller-directly)
- [API reference](#api-reference)
- [Platform support](#platform-support)
- [Troubleshooting](#troubleshooting)
- [Further reading](#further-reading)
- [Contributing](#contributing)
- [License](#license)

---

## Highlights

- **`SVGAEasyPlayer`** — drop-in widget; play from assets or network with
  one line of code.
- **Three playback modes** — infinite loop, play once, or repeat *N* times,
  each with an `onFinished` callback.
- **Audio control** — mute/unmute embedded audio tracks at the widget or
  controller level.
- **Intelligent disk cache** — persistent, size- and age-bounded, shared
  across widgets and app launches.
- **Silent background precaching** — hand it a list of URLs and it warms
  the cache on its own; later playback starts instantly from disk.
- **Poison-resistant cache** — payloads are validated before they reach the
  cache and corrupted entries are self-healed on read.
- **Dynamic content** — override text, swap images, add custom drawings,
  or hide layers at runtime.
- **First-class controller** — full `AnimationController` API with frame
  seeking, status listeners, and `SingleTickerProviderStateMixin` support.

---

## Install

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_svga_easyplayer: ^0.0.7
```

Then run:

```sh
flutter pub get
```

Import it where needed:

```dart
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
```

---

## Quick start

The minimum you need to render an SVGA file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('SVGA Demo')),
        body: const Center(
          child: SVGAEasyPlayer(
            assetsName: 'assets/sample.svga',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
```

Don't forget to register the asset in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/sample.svga
```

---

## Loading animations

`SVGAEasyPlayer` accepts either an asset path or a network URL.

### From assets

```dart
SVGAEasyPlayer(
  assetsName: 'assets/sample.svga',
  fit: BoxFit.contain,
);
```

### From a network URL

```dart
SVGAEasyPlayer(
  resUrl: 'https://example.com/sample.svga',
  fit: BoxFit.cover,
);
```

Network loads are cached automatically on first successful decode; see
[Caching](#caching) and [Background precaching](#background-precaching)
for how to make subsequent renders instantaneous.

---

## Playback modes

`SVGAEasyPlayer` exposes three playback modes through the `loops` parameter.

| `loops` | Behaviour                          | `onFinished` |
| :-----: | ---------------------------------- | :----------: |
| `null`  | Infinite loop *(default)*          | never fires  |
| `0`     | Play once                          | after 1 play |
| `n > 0` | Play once, then repeat *n* times   | after n + 1  |

```dart
// Infinite loop — perfect for loaders and backgrounds.
SVGAEasyPlayer(assetsName: 'assets/loading.svga');

// Play once — perfect for splash / intro animations.
SVGAEasyPlayer(
  assetsName: 'assets/splash.svga',
  loops: 0,
  onFinished: () => Navigator.of(context).pushReplacementNamed('/home'),
);

// Repeat three times — perfect for celebration effects.
SVGAEasyPlayer(
  assetsName: 'assets/celebration.svga',
  loops: 3,
  onFinished: () => debugPrint('done!'),
);
```

See [PLAYBACK_MODES.md](PLAYBACK_MODES.md) for a deeper guide and more
recipes.

---

## Audio control

SVGA files can embed audio tracks. Mute or unmute them without stopping
the animation:

```dart
// From the widget.
SVGAEasyPlayer(
  assetsName: 'assets/with_audio.svga',
  isMute: true,
);

// From a controller you own.
final controller = SVGAAnimationController(vsync: this);
controller.isMute = true;
```

Toggling `isMute` at runtime takes effect on the next frame — no reload
required.

---

## Caching

A persistent disk cache is enabled by default. Entries are keyed by URL
(or `assets:<path>` for bundled assets), bounded by size and age, and
survive app restarts.

### Per-widget controls

```dart
// Default: read from cache if available, store on first successful load.
SVGAEasyPlayer(resUrl: 'https://cdn.example.com/anim.svga');

// Always fetch fresh — useful for dynamic content.
SVGAEasyPlayer(
  resUrl: 'https://api.example.com/dynamic.svga',
  useCache: false,
);

// One-shot animation — clear the entry when the widget disposes.
SVGAEasyPlayer(
  assetsName: 'assets/one_time.svga',
  loops: 0,
  clearCacheOnDispose: true,
  onFinished: () => Navigator.pop(context),
);
```

### Global configuration

```dart
// Tune once at startup (all values optional).
SVGACache.shared
  ..setMaxCacheSize(100 * 1024 * 1024)        // 100 MB
  ..setMaxAge(const Duration(days: 7));        // evict after 7 days

// Inspect or manage the cache.
final exists  = await SVGACache.shared.contains('https://…/anim.svga');
final stats   = await SVGACache.shared.getStats();
await SVGACache.shared.remove('https://…/anim.svga');
await SVGACache.shared.clear();
```

Reliability: corrupt payloads (e.g. an HTML 404 page returned with a `200`
status by a misconfigured CDN) are detected and **never written to the
cache**. If a previously cached entry ever fails to decode it is evicted
and refetched automatically — playback self-heals without any code on
your side.

For advanced cache patterns see [CACHE.md](CACHE.md) and
[CACHE_CONTROL.md](CACHE_CONTROL.md).

---

## Background precaching

Hand `SVGAPrecacheManager` a list of URLs at startup (or any time), and
it silently downloads and stores them in the same cache the player reads
from. When you later render `SVGAEasyPlayer(resUrl: url)` for any of
those URLs, **it plays instantly — no network round-trip, no loading
indicator flash.**

### In `main()`

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Fire-and-forget — returns immediately, work happens in the background.
  SVGAPrecacheManager.shared.precache(
    const [
      'https://cdn.example.com/a.svga',
      'https://cdn.example.com/b.svga',
      'https://cdn.example.com/c.svga',
    ],
    delay:       const Duration(seconds: 1),  // let startup settle first
    concurrency: 3,                            // parallel downloads
    timeout:     const Duration(seconds: 15),  // per-request timeout
  );

  runApp(const MyApp());
}
```

### From any screen

You are not limited to `main()`. Precache from `initState`, after login,
on a button tap, or whenever your app knows which animations are coming:

```dart
@override
void initState() {
  super.initState();
  SVGAPrecacheManager.shared.precache(const [
    'https://cdn.example.com/home_hero.svga',
    'https://cdn.example.com/home_badge.svga',
  ]);
}
```

### With progress or a result

```dart
final result = await SVGAPrecacheManager.shared.precache(
  urls,
  onProgress: (done, total, url, ok) {
    debugPrint('[$done/$total] ${ok ? "OK" : "FAIL"}  $url');
  },
);

// SVGAPrecacheResult(total: 6, completed: 6, hits: 2, fetched: 4, failed: 0, cancelled: false)
debugPrint('$result');
```

### Assets, cancellation, and state

```dart
// Warm bundled assets.
SVGAPrecacheManager.shared.precacheAssets(const [
  'assets/intro.svga',
  'assets/celebration.svga',
]);

// Cancel any in-flight batch; in-progress downloads still finish.
SVGAPrecacheManager.shared.cancel();

// Check whether anything is running.
if (SVGAPrecacheManager.shared.isRunning) { /* … */ }
```

### Why it's safe to call on every launch

- **Skip-if-cached** — URLs with a valid entry are skipped without any
  network I/O.
- **Deduplicated** — overlapping batches requesting the same URL result
  in a single download.
- **Failure-tolerant** — network, timeout, asset, and disk errors are
  swallowed; one bad URL never blocks the rest.
- **Validated before storage** — only payloads that look like a valid
  SVGA (zlib) file are written to the cache.
- **Global-setting aware** — honours `SVGACache.shared`'s enable flag,
  `maxCacheSize`, and `maxAge`.

---

## Dynamic content

Replace text, swap images, add a custom drawer, or hide a layer at
runtime. These operate on the `dynamicItem` of the decoded `MovieEntity`.

### Replace text

```dart
controller.videoItem!.dynamicItem.setText(
  TextPainter(
    text: const TextSpan(
      text: 'Hello SVGA!',
      style: TextStyle(color: Colors.red, fontSize: 18),
    ),
    textDirection: TextDirection.ltr,
  ),
  'text_layer',
);
```

### Swap an image

```dart
controller.videoItem!.dynamicItem.setImageWithUrl(
  'https://example.com/new_image.png',
  'image_layer',
);
```

### Draw on top of a layer

```dart
controller.videoItem!.dynamicItem.setDynamicDrawer(
  (canvas, frameIndex) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 88, 88),
      Paint()..color = Colors.red,
    );
  },
  'banner',
);
```

### Hide a layer

```dart
controller.videoItem!.dynamicItem.setHidden(true, 'layer_to_hide');
```

---

## Using the controller directly

When you need manual control — for timeline scrubbing, status listeners,
or interop with other animations — use `SVGAAnimationController` and
`SVGAImage` directly:

```dart
class MyAnimated extends StatefulWidget {
  const MyAnimated({super.key});

  @override
  State<MyAnimated> createState() => _MyAnimatedState();
}

class _MyAnimatedState extends State<MyAnimated>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _controller =
      SVGAAnimationController(vsync: this)..isMute = true;

  @override
  void initState() {
    super.initState();
    SVGAParser.shared.decodeFromAssets('assets/sample.svga').then((video) {
      if (!mounted) {
        video.dispose();
        return;
      }
      _controller
        ..videoItem = video
        ..repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SVGAImage(_controller);
}
```

Controller playback controls:

```dart
controller.forward();  // play once
controller.repeat();   // loop
controller.stop();     // pause
controller.value = 0;  // seek to first frame
```

---

## API reference

### `SVGAEasyPlayer`

| Parameter             | Type              | Default        | Description                                                                |
| --------------------- | ----------------- | -------------- | -------------------------------------------------------------------------- |
| `assetsName`          | `String?`         | —              | Path to a bundled asset. Mutually exclusive with `resUrl`.                 |
| `resUrl`              | `String?`         | —              | Network URL. Mutually exclusive with `assetsName`.                         |
| `fit`                 | `BoxFit`          | `contain`      | How the animation is scaled inside the widget.                             |
| `loops`               | `int?`            | `null`         | `null` = infinite, `0` = play once, `n > 0` = play once + repeat *n*.      |
| `onFinished`          | `VoidCallback?`   | —              | Called after the configured playback completes.                            |
| `isMute`              | `bool`            | `false`        | Mute embedded audio.                                                       |
| `useCache`            | `bool`            | `true`         | Read from and write to the global cache for this widget.                   |
| `clearCacheOnDispose` | `bool`            | `false`        | Remove the cache entry for this source when the widget is disposed.        |

### `SVGAParser`

| Call                                       | Description                                            |
| ------------------------------------------ | ------------------------------------------------------ |
| `SVGAParser.shared.decodeFromURL(url)`     | Decode from a URL (uses and populates the cache).      |
| `SVGAParser.shared.decodeFromAssets(path)` | Decode from a bundled asset (uses and populates cache).|
| `SVGAParser.shared.decodeFromBuffer(bytes)`| Decode a raw `List<int>`/`Uint8List` payload.          |

### `SVGACache`

| Call                                   | Description                                            |
| -------------------------------------- | ------------------------------------------------------ |
| `setEnabled(bool)`                     | Globally enable or disable caching.                    |
| `setMaxCacheSize(bytes)`               | Set the cache size ceiling (default `100 MB`).         |
| `setMaxAge(Duration)`                  | Set the per-entry expiry (default `7 days`).           |
| `contains(source)`                     | Whether a valid entry exists for `source`.             |
| `remove(source)`                       | Delete one entry.                                      |
| `clear()`                              | Delete every entry.                                    |
| `getStats()`                           | `{enabled, size, maxSize, fileCount, maxAge}` snapshot.|

### `SVGAPrecacheManager`

| Call                                                        | Description                                                 |
| ----------------------------------------------------------- | ----------------------------------------------------------- |
| `precache(urls, {delay, concurrency, timeout, onProgress})` | Fire-and-forget precache of network URLs. Returns a result. |
| `precacheAssets(paths, {delay, concurrency, onProgress})`   | Same, for bundled assets.                                   |
| `cancel()`                                                  | Stop picking up new items from in-flight batches.           |
| `isRunning`                                                 | `true` while any batch is still active.                     |

### `SVGAAnimationController`

Inherits from `AnimationController` — use `forward`, `repeat`, `stop`,
`reset`, `value`, and status listeners as usual. Adds:

| Member           | Description                                        |
| ---------------- | -------------------------------------------------- |
| `videoItem`      | The decoded `MovieEntity` to render.               |
| `isMute`         | Mute embedded audio.                               |
| `currentFrame`   | Current frame index (`0`-based).                   |
| `frames`         | Total frame count.                                 |

---

## Platform support

| Platform | Rendering | Audio |
| -------- | :-------: | :---: |
| Android  | ✓         | ✓     |
| iOS      | ✓         | ✓     |
| macOS    | ✓         | ✓     |
| Linux    | ✓         | ✓     |
| Windows  | ✓         | ✓     |
| Web      | ✓         | —     |

---

## Troubleshooting

**A black box where the animation should be.** The asset is missing or
not registered. Add it under `flutter/assets:` in `pubspec.yaml` and
re-run `flutter pub get`.

**`Exception caught by SVGAEasyPlayer: Filter error, bad data`.** The
bytes fed to the decoder are not a valid SVGA payload. Since `0.0.7` the
cache refuses to store bad payloads and self-heals previously poisoned
entries on next read, so a single hiccup cannot keep failing forever.
Check that the URL actually returns an `.svga` file (try `curl -I <url>`
or open it in a browser).

**Network URL won't load.** Serve the file over HTTPS, verify it in a
browser, and make sure platform network permissions are configured (e.g.
iOS ATS exceptions for plain HTTP during development).

**Animation renders but never moves.** You probably set the `videoItem`
without calling `forward()`, `repeat()`, or any playback method on the
controller.

---

## Further reading

- [CHANGELOG.md](CHANGELOG.md) — release notes.
- [PLAYBACK_MODES.md](PLAYBACK_MODES.md) — detailed playback-mode guide.
- [CACHE.md](CACHE.md) — cache internals and patterns.
- [CACHE_CONTROL.md](CACHE_CONTROL.md) — advanced cache management.
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) — cheat sheet.
- [`example/`](example) — interactive demo app covering every feature.

---

## Contributing

- Found a bug or want a feature? [Open an issue](https://github.com/zamansheikh/flutter_svga_easyplayer/issues).
- Pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for
  guidelines.

### Maintainer

- **[zamansheikh](https://github.com/zamansheikh)** — lead developer and
  maintainer.

### Contributors

| Contributor                                               | Contribution                                  |
| --------------------------------------------------------- | --------------------------------------------- |
| [wonderkidshihab](https://github.com/wonderkidshihab)     | Fixed repeated music playback bug ([#3](https://github.com/zamansheikh/flutter_svga_easyplayer/issues/3)) |

---

## License

Released under the [MIT License](LICENSE).
