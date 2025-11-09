# SVGAEasyPlayer Cache Control Guide

## Overview

`SVGAEasyPlayer` now includes built-in cache control features, allowing you to manage caching behavior on a per-widget basis. This gives you fine-grained control over performance, storage, and data freshness.

## Features

### ✅ Per-Widget Cache Control
- Enable or disable caching for individual players
- Automatic cache cleanup on widget disposal
- Works seamlessly with global cache settings

### 🎯 Default Behavior
By default, `SVGAEasyPlayer`:
- **Uses cache** (`useCache: true`)
- **Keeps cached data** after disposal (`clearCacheOnDispose: false`)
- Respects global cache settings from `SVGACache.shared`

## API Reference

### Cache Control Parameters

#### `useCache` (bool, default: `true`)

Controls whether this specific widget uses caching.

```dart
// With cache (default - faster on subsequent loads)
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  useCache: true, // default
)

// Without cache (always loads fresh)
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  useCache: false, // bypass cache
)
```

**When to use `useCache: false`:**
- Testing different versions of the same animation
- Real-time/dynamic content that changes frequently
- Privacy-sensitive animations
- Debugging cache-related issues

#### `clearCacheOnDispose` (bool, default: `false`)

Automatically removes the animation from cache when the widget is disposed.

```dart
// Keep in cache (default)
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  clearCacheOnDispose: false, // default
)

// Auto-cleanup when disposed
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  clearCacheOnDispose: true, // cleanup on dispose
)
```

**When to use `clearCacheOnDispose: true`:**
- One-time celebration animations
- Temporary splash screens
- Privacy-sensitive content
- Reducing storage footprint
- Testing/development scenarios

## Usage Examples

### Example 1: Cached Animation (Default)

Standard usage with caching enabled:

```dart
class LoadingScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SVGAEasyPlayer(
      assetsName: "assets/loading.svga",
      // useCache: true by default
      // Loads fast on repeated displays
    );
  }
}
```

**Benefits:**
- ✅ Fast loading on subsequent uses
- ✅ Reduced bandwidth for network resources
- ✅ Better offline experience

### Example 2: Fresh Data Every Time

Bypass cache for dynamic content:

```dart
class DynamicContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SVGAEasyPlayer(
      resUrl: "https://api.example.com/today-animation.svga",
      useCache: false, // Always fetch fresh
      loops: 0,
    );
  }
}
```

**Benefits:**
- ✅ Always up-to-date content
- ✅ No stale data issues
- ✅ Testing flexibility

### Example 3: One-Time Celebration with Auto-Cleanup

Animation that cleans up after itself:

```dart
class AchievementPopup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SVGAEasyPlayer(
        assetsName: "assets/achievement.svga",
        loops: 2, // Play 3 times total
        useCache: true, // Cache for performance
        clearCacheOnDispose: true, // Cleanup when closed
        onFinished: () {
          Navigator.pop(context); // Close dialog
          // Cache is automatically cleared here
        },
      ),
    );
  }
}
```

**Benefits:**
- ✅ Fast loading
- ✅ Automatic cleanup
- ✅ Saves storage space

### Example 4: Privacy-Sensitive Content

Don't cache sensitive animations:

```dart
class PrivateDataViewer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SVGAEasyPlayer(
      resUrl: "https://secure.example.com/user-data.svga",
      useCache: false, // Don't store on disk
      clearCacheOnDispose: true, // Extra safety
    );
  }
}
```

**Benefits:**
- ✅ No data persistence
- ✅ Enhanced privacy
- ✅ Compliance with security policies

### Example 5: Development/Testing

Disable cache during development:

```dart
class AnimationPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SVGAEasyPlayer(
      assetsName: "assets/work_in_progress.svga",
      useCache: kReleaseMode, // Cache in release, not in debug
      loops: 0,
    );
  }
}
```

**Benefits:**
- ✅ See changes immediately
- ✅ No cache invalidation needed
- ✅ Faster development iteration

## Combining with Playback Control

Cache control works seamlessly with playback modes:

### Cached One-Time Animation

```dart
SVGAEasyPlayer(
  assetsName: "assets/intro.svga",
  loops: 0, // Play once
  useCache: true, // Cache for fast loading
  onFinished: () => Navigator.push(...),
)
```

### Temporary Effect with Cleanup

```dart
SVGAEasyPlayer(
  assetsName: "assets/explosion.svga",
  loops: 0, // Play once
  clearCacheOnDispose: true, // Clean up after
  onFinished: () => setState(() => _showEffect = false),
)
```

### Fresh Repeated Animation

```dart
SVGAEasyPlayer(
  resUrl: "https://api.example.com/live-ticker.svga",
  loops: null, // Loop forever
  useCache: false, // Always fresh data
)
```

## Cache Control Flow

### How `useCache` Works

```
useCache: true (default)
  ├─> Check cache first
  ├─> If found: Load from cache (fast)
  └─> If not found:
      ├─> Load from source
      └─> Store in cache for next time

useCache: false
  ├─> Temporarily disable global cache
  ├─> Load from source
  ├─> Re-enable global cache
  └─> Nothing stored to cache
```

### How `clearCacheOnDispose` Works

```
Widget lifecycle:
  initState() ─> Load animation (may use cache)
       ↓
  build() ─────> Display animation
       ↓
  dispose() ───> If clearCacheOnDispose: true
                 └─> Remove from cache
```

## Global vs Per-Widget Control

### Global Cache Settings

Affect all SVGA loading across the app:

```dart
void main() {
  // Global configuration
  SVGACache.shared.setEnabled(true);
  SVGACache.shared.setMaxCacheSize(100 * 1024 * 1024); // 100MB
  SVGACache.shared.setMaxAge(Duration(days: 7));
  
  runApp(MyApp());
}
```

### Per-Widget Overrides

Individual widgets can override global settings:

```dart
// Global cache is enabled, but this widget bypasses it
SVGAEasyPlayer(
  assetsName: "assets/test.svga",
  useCache: false, // Override global setting
)
```

### Interaction Matrix

| Global Cache | `useCache` | Result |
|--------------|------------|---------|
| Enabled | `true` | ✅ Caching active |
| Enabled | `false` | ❌ Caching bypassed |
| Disabled | `true` | ❌ No caching (global wins) |
| Disabled | `false` | ❌ No caching |

## Performance Considerations

### Memory Impact
- **useCache: true**: Minimal - only affects disk I/O
- **useCache: false**: No additional memory overhead
- **clearCacheOnDispose**: Saves disk space over time

### Loading Speed Comparison

```dart
// First load: ~200-500ms (download + parse)
// Cached load: ~10-50ms (disk read + parse)
// Speed up: 5-50x faster!
```

### Storage Impact

```dart
// Get cache statistics
final stats = await SVGACache.shared.getStats();
print('Cache size: ${stats['size']} bytes');
print('File count: ${stats['fileCount']}');
```

## Best Practices

### ✅ DO

1. **Use caching for static content**
   ```dart
   SVGAEasyPlayer(assetsName: "assets/logo.svga") // useCache: true by default
   ```

2. **Disable cache for dynamic content**
   ```dart
   SVGAEasyPlayer(resUrl: dynamicUrl, useCache: false)
   ```

3. **Clear cache for one-time animations**
   ```dart
   SVGAEasyPlayer(assetsName: "assets/splash.svga", clearCacheOnDispose: true)
   ```

4. **Monitor cache size in production**
   ```dart
   final stats = await SVGACache.shared.getStats();
   analytics.log('cache_size', stats['size']);
   ```

### ❌ DON'T

1. **Don't disable cache unnecessarily**
   ```dart
   // Bad: Slower performance without benefit
   SVGAEasyPlayer(assetsName: "assets/static.svga", useCache: false)
   ```

2. **Don't use clearCacheOnDispose for frequently used animations**
   ```dart
   // Bad: Re-downloads every time
   SVGAEasyPlayer(assetsName: "assets/common.svga", clearCacheOnDispose: true)
   ```

3. **Don't forget to handle cache in testing**
   ```dart
   // Good: Clear cache before tests
   setUp(() async {
     await SVGACache.shared.clear();
   });
   ```

## Troubleshooting

### Animation Not Loading Fresh?

Check if cache is interfering:

```dart
// Option 1: Disable cache for this widget
SVGAEasyPlayer(resUrl: url, useCache: false)

// Option 2: Clear specific cache item
await SVGACache.shared.remove(url);

// Option 3: Clear all cache
await SVGACache.shared.clear();
```

### Cache Growing Too Large?

Adjust global settings:

```dart
// Reduce max size
SVGACache.shared.setMaxCacheSize(50 * 1024 * 1024); // 50MB

// Reduce max age
SVGACache.shared.setMaxAge(Duration(days: 3));

// Or clear old entries
await SVGACache.shared.clear();
```

### Widget Disposed But Cache Not Cleared?

Ensure `clearCacheOnDispose` is set:

```dart
SVGAEasyPlayer(
  assetsName: "assets/temp.svga",
  clearCacheOnDispose: true, // Important!
)
```

## Examples in Action

See the complete working example:

```bash
cd example
flutter run
```

Then tap **"Cache Control in EasyPlayer"** to see:
- Live cache statistics
- Cache vs no-cache comparison
- Auto-cleanup demonstration
- Global cache management

## Summary

`SVGAEasyPlayer` cache control provides:

✅ **Performance**: Fast loading with smart caching  
✅ **Flexibility**: Per-widget cache control  
✅ **Storage**: Automatic cleanup options  
✅ **Privacy**: Disable caching for sensitive content  
✅ **Testing**: Easy cache bypass for development  

All while maintaining 100% backward compatibility with existing code!
