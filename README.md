# flutter_svga_easyplayer

A **Flutter package** for parsing and rendering **SVGA animations** efficiently with powerful **EasyPlayer** features.  
SVGA is a lightweight and powerful animation format used for **dynamic UI effects** in mobile applications.

<p align="center">
  <img src="https://raw.githubusercontent.com/zamansheikh/flutter_svga_easyplayer/master/example.gif" width="300"/>
  <img src="https://raw.githubusercontent.com/zamansheikh/flutter_svga_easyplayer/master/example1.gif" width="300"/>
</p>

---

## 🚀 **Features**

✔️ Parse and render **SVGA animations** in Flutter.  
✔️ Load SVGA files from **assets** and **network URLs**.  
✔️ **Intelligent caching system** for faster loading and reduced network usage.  
✔️ **Per-widget cache control**: Enable/disable caching and auto-cleanup per player.  
✔️ **Playback control modes**: infinite loop, play once, or repeat N times with completion callbacks.  
✔️ Supports **custom dynamic elements** (text, images, animations).  
✔️ **Optimized playback performance** with animation controllers.  
✔️ **Integrated audio playback** within SVGA animations.  
✔️ Works on **Android & iOS** (Web & Desktop support coming soon).  
✔️ Easy **loop, stop, and seek** functions.

---

## 📌 **Installation**

Add **flutter_svga_easyplayer** to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_svga_easyplayer: ^0.0.1

```
Then, install dependencies:

```sh
flutter pub get
```

---

## 🎬 **Basic Usage**

### ✅ **Playing an SVGA Animation from Assets**
```dart
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Flutter SVGA Example")),
        body: Center(
          child: SVGAEasyPlayer(
            assetsName: "assets/sample_with_audio.svga",
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
```

---

## 🌍 **Playing SVGA from a Network URL**
```dart
SVGAEasyPlayer(
  resUrl: "https://example.com/sample.svga",
  fit: BoxFit.cover,
);
```

---

## 🎮 **Playback Control Modes (NEW!)**

`SVGAEasyPlayer` now supports three powerful playback modes:

### ✅ **Infinite Loop (Default)**
```dart
SVGAEasyPlayer(
  assetsName: "assets/loading.svga",
  // loops: null (default) - plays infinitely
)
```

### ✅ **Play Once**
```dart
SVGAEasyPlayer(
  assetsName: "assets/splash.svga",
  loops: 0, // Play once then stop
  onFinished: () {
    print("Animation completed!");
    // Navigate to next screen, etc.
  },
)
```

### ✅ **Repeat N Times**
```dart
SVGAEasyPlayer(
  assetsName: "assets/celebration.svga",
  loops: 3, // Play 4 times total (1 + 3 repeats)
  onFinished: () {
    print("All repetitions completed!");
  },
)
```

📖 **[Read the full Playback Modes Guide](PLAYBACK_MODES.md)** for detailed examples and use cases.

---

## 💾 **Cache Control in EasyPlayer (NEW!)**

Control caching behavior on a per-widget basis:

### ✅ **With Cache (Default - Faster)**
```dart
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  useCache: true, // default - uses cache for fast loading
)
```

### ✅ **Without Cache (Always Fresh)**
```dart
SVGAEasyPlayer(
  resUrl: "https://api.example.com/dynamic.svga",
  useCache: false, // bypass cache, always load fresh
)
```

### ✅ **Auto-Cleanup on Dispose**
```dart
SVGAEasyPlayer(
  assetsName: "assets/one-time.svga",
  clearCacheOnDispose: true, // removes from cache when disposed
  loops: 0,
  onFinished: () => Navigator.pop(),
)
```

📖 **[Read the Cache Control Guide](CACHE_CONTROL.md)** for advanced cache management strategies.

---

## 🎭 **Advanced Usage: Using SVGAAnimationController**

### ✅ **Controlling Animation Playback**
```dart
class MySVGAWidget extends StatefulWidget {
  @override
  _MySVGAWidgetState createState() => _MySVGAWidgetState();
}

class _MySVGAWidgetState extends State<MySVGAWidget>
    with SingleTickerProviderStateMixin {
  late SVGAAnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    SVGAParser.shared.decodeFromAssets("assets/sample.svga").then((video) {
      _controller.videoItem = video;
      _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SVGAImage(_controller);
  }
}
```

---

## 🎨 **Customization & Dynamic Elements**

### ✅ **Adding Dynamic Text**
```dart
controller.videoItem!.dynamicItem.setText(
  TextPainter(
    text: TextSpan(
      text: "Hello SVGA!",
      style: TextStyle(color: Colors.red, fontSize: 18),
    ),
    textDirection: TextDirection.ltr,
  ),
  "text_layer",
);
```

---

### ✅ **Replacing an Image Dynamically**
```dart
controller.videoItem!.dynamicItem.setImageWithUrl(
  "https://example.com/new_image.png",
  "image_layer",
);
```

---

### ✅ **Hiding a Layer**
```dart
controller.videoItem!.dynamicItem.setHidden(true, "layer_to_hide");
```

---

## 🗄️ **Caching (New!)**

**Automatic performance optimization with zero breaking changes:**

```dart
// Caching works automatically - no code changes needed!
final animation = await SVGAParser.shared.decodeFromURL(
  "https://example.com/animation.svga"
);

// Optional: Configure cache settings
SVGACache.shared.setMaxCacheSize(50 * 1024 * 1024); // 50MB
SVGACache.shared.setMaxAge(const Duration(days: 3)); // 3 days

// Optional: Manage cache
await SVGACache.shared.clear(); // Clear all cache
final stats = await SVGACache.shared.getStats(); // Get cache info
```

**📋 See [CACHE.md](CACHE.md) for complete caching documentation and examples.**

---

## 🎯 **Playback Controls**
```dart
controller.forward();  // Play once
controller.repeat();   // Loop playback
controller.stop();     // Stop animation
controller.value = 0;  // Reset to first frame
```

---

## 🛠 **Common Issues & Solutions**

### ❌ **Black Screen when Loading SVGA**
✅ **Solution:** Ensure your `svga` files are correctly placed inside `assets/` and registered in `pubspec.yaml`.
```yaml
flutter:
  assets:
    - assets/sample.svga
```

---

### ❌ **SVGA Not Loading from Network**
✅ **Solution:** Ensure the SVGA file is accessible via HTTPS. Test the URL in a browser.
```dart
SVGAEasyPlayer(
  resUrl: "https://example.com/sample.svga",
  fit: BoxFit.cover,
);
```

---

### ❌ **Animation Freezes or Doesn't Play**
✅ **Solution:** Use `setState` after loading SVGA to rebuild the widget.
```dart
setState(() {
  _controller.videoItem = video;
});
```

---

## 📱 **Supported Platforms**

| Platform | Supported | Audio Support |
|----------|-----------|---------------|
| ✅ Android | ✔️ Yes | ✔️ Yes |
| ✅ iOS | ✔️ Yes | ✔️ Yes |
| ✅ Linux | ✔️ Yes | ✔️ Yes |
| ✅ Web | ✔️ Yes | ❌ No |
| ✅ macOS | ✔️ Yes | ✔️ Yes |
| ✅ Desktop | ✔️ Yes | ✔️ Yes |

---

## 🔄 **Changelog**
See the latest changes in [`CHANGELOG.md`](CHANGELOG.md).

---

## 📜 **License**
This package is licensed under the **MIT License**. See [`LICENSE`](LICENSE) for details.

---

## 🤝 **Contributing**
- If you find a **bug**, report it [here](https://github.com/zamansheikh/flutter_svga_easyplayer/issues).
- Pull requests are welcome! See [`CONTRIBUTING.md`](CONTRIBUTING.md) for guidelines.

---

## 👨‍💻 **Authors & Contributors**

### 🏗 **Core Author**
- **[zamansheikh](https://github.com/zamansheikh)** — Lead Developer, Maintainer, and Flutter Integration Engineer.


### 🤝 **Contributors**
Special thanks to the amazing contributors who improved **flutter_svga**:

| Contributor | Contribution | GitHub |
|--------------|--------------|--------|
| **[wonderkidshihab](https://github.com/wonderkidshihab)** | Fixed repeated music playback bug (#3) | 🧩 |

> Want to contribute? Read [CONTRIBUTING.md](CONTRIBUTING.md) and submit your PR — we’d love your help!

---

🚀 **Enjoy using SVGA animations in your Flutter app!** 🚀

