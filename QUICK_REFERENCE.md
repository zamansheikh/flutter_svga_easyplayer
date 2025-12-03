# SVGAEasyPlayer - Quick Reference

## 🎯 Three Playback Modes + Cache Control

### 1️⃣ Infinite Loop (Default)

```dart
SVGAEasyPlayer(assetsName: "assets/animation.svga")
```

**Behavior:** Loops forever  
**Use for:** Loading indicators, background animations

---

### 2️⃣ Play Once

```dart
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",

  loops: 0,
  onFinished: () => print("Done!"),
)
```

**Behavior:** Plays 1 time, then stops  
**Use for:** Splash screens, onboarding, celebrations

**For Mute Audio:** Pass isMute: true

```dart
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  isMute: true,
  loops: 0,
  onFinished: () => print("Done!"),
)
```

---

### 3️⃣ Repeat N Times

```dart
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  loops: 3,  // Plays 4 times total
  onFinished: () => print("Finished all repeats!"),
)
```

**Behavior:** Plays (N + 1) times, then stops  
**Use for:** Notifications, limited celebrations

---

## 💾 Cache Control

### With Cache (Default - Faster)

```dart
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  useCache: true, // default - loads from cache if available
)
```

### Without Cache (Always Fresh)

```dart
SVGAEasyPlayer(
  resUrl: "https://api.example.com/animation.svga",
  useCache: false, // bypass cache, always load fresh
)
```

### Auto-Cleanup on Dispose

```dart
SVGAEasyPlayer(
  assetsName: "assets/one-time.svga",
  clearCacheOnDispose: true, // removes from cache when disposed
  loops: 0,
)
```

---

## 📊 Complete Parameter Reference

| Parameter             | Type            | Default          | Description                                |
| --------------------- | --------------- | ---------------- | ------------------------------------------ |
| `assetsName`          | `String?`       | `null`           | Asset path to SVGA file                    |
| `resUrl`              | `String?`       | `null`           | Network URL to SVGA file                   |
| `fit`                 | `BoxFit`        | `BoxFit.contain` | How to fit animation                       |
| `loops`               | `int?`          | `null`           | Repeat count (null=∞, 0=once, N=N+1 times) |
| `onFinished`          | `VoidCallback?` | `null`           | Called when animation completes            |
| `useCache`            | `bool`          | `true`           | Use caching for this animation             |
| `clearCacheOnDispose` | `bool`          | `false`          | Clear cache when widget disposed           |

---

## 📋 Loops Behavior

| `loops` Value    | Total Plays  | Calls `onFinished` |
| ---------------- | ------------ | ------------------ |
| `null` (default) | ∞ (Infinite) | Never ❌           |
| `0`              | 1 time       | Yes ✅             |
| `1`              | 2 times      | Yes ✅             |
| `3`              | 4 times      | Yes ✅             |
| `N`              | N + 1 times  | Yes ✅             |

---

## 🔥 Quick Examples

### Auto-Navigate After Animation

```dart
SVGAEasyPlayer(
  assetsName: "assets/intro.svga",
  loops: 0,
  useCache: true,
  onFinished: () => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => HomeScreen()),
  ),
)
```

### One-Time Celebration with Cleanup

```dart
SVGAEasyPlayer(
  assetsName: "assets/achievement.svga",
  loops: 2, // Play 3 times
  clearCacheOnDispose: true, // Clean up after
  onFinished: () => setState(() => _showCelebration = false),
)
```

### Dynamic Content (No Cache)

```dart
SVGAEasyPlayer(
  resUrl: "https://api.example.com/live-data.svga",
  useCache: false, // Always fresh
  loops: null, // Loop forever
)
```

### Replay Button

```dart
int _key = 0;

// Widget
SVGAEasyPlayer(
  key: ValueKey(_key),
  assetsName: "assets/anim.svga",
  loops: 0,
  useCache: true,
)

// Button
ElevatedButton(
  onPressed: () => setState(() => _key++),
  child: Text("Replay"),
)
```

### Privacy-Sensitive Animation

```dart
SVGAEasyPlayer(
  resUrl: "https://secure.example.com/user-data.svga",
  useCache: false, // Don't store on disk
  clearCacheOnDispose: true, // Extra safety
  loops: 0,
)
```

---

## ⚡ Common Patterns

**Loading indicator (cached, infinite):**

```dart
loops: null, useCache: true
```

**One-time splash (cached, auto-nav):**

```dart
loops: 0, useCache: true, onFinished: () => navigate()
```

**Temporary effect (no cache, auto-cleanup):**

```dart
loops: 0, useCache: false, clearCacheOnDispose: true
```

**Dynamic content (no cache, infinite):**

```dart
loops: null, useCache: false
```

**Celebration (cached, limited repeats, cleanup):**

```dart
loops: 2, useCache: true, clearCacheOnDispose: true
```

---

## 🚨 Common Mistakes

❌ **Wrong:** Expecting 3 plays with `loops: 3`  
✅ **Right:** `loops: 3` means 4 total plays (1 initial + 3 repeats)

❌ **Wrong:** Using `onFinished` with `loops: null`  
✅ **Right:** Infinite loops never finish, use `loops: 0` or `loops: N`

❌ **Wrong:** Disabling cache for static assets  
✅ **Right:** Use `useCache: true` (default) for better performance

❌ **Wrong:** Forgetting to set `clearCacheOnDispose` for temporary animations  
✅ **Right:** Set `clearCacheOnDispose: true` to save storage

---

## 💾 Global Cache Management

```dart
// Check cache statistics
final stats = await SVGACache.shared.getStats();
print('Cache: ${stats['fileCount']} files, ${stats['size']} bytes');

// Clear all cache
await SVGACache.shared.clear();

// Enable/disable globally
SVGACache.shared.setEnabled(true/false);

// Configure limits
SVGACache.shared.setMaxCacheSize(100 * 1024 * 1024); // 100MB
SVGACache.shared.setMaxAge(Duration(days: 7));
```

---

## 📚 Full Documentation

- **[PLAYBACK_MODES.md](PLAYBACK_MODES.md)** - Detailed playback control guide
- **[CACHE_CONTROL.md](CACHE_CONTROL.md)** - Complete cache control documentation
- **[CACHE.md](CACHE.md)** - Global cache system overview

---

## 🎮 Try It!

Run the example app:

```bash
cd example && flutter run
```

Then explore:

- **"Playback Modes Example"** - See all playback modes
- **"Cache Control in EasyPlayer"** - Interactive cache demo
- **"Cache Example & Configuration"** - Global cache management
