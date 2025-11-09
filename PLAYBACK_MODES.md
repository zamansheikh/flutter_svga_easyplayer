# SVGAEasyPlayer Playback Modes

This document explains the new playback control features added to `SVGAEasyPlayer`.

## Overview

`SVGAEasyPlayer` now supports three playback modes to give you full control over how your SVGA animations play:

1. **Infinite Repeat** (Default) - Animation loops forever
2. **Play Once** - Animation plays one time and stops
3. **Repeat N Times** - Animation repeats a specific number of times

Additionally, an `onFinished` callback has been added to execute code when the animation completes.

## Features

### 1. Infinite Repeat (Default Behavior)

This is the original behavior - the animation loops continuously without stopping.

```dart
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  // loops: null is the default
)
```

**Use Cases:**
- Background animations
- Loading indicators
- Ambient effects
- Decorative animations that should always play

### 2. Play Once

Play the animation one time and stop. Perfect for one-time events.

```dart
SVGAEasyPlayer(
  assetsName: "assets/celebration.svga",
  loops: 0, // Play once
  onFinished: () {
    print("Animation completed!");
    // Navigate to next screen, show message, etc.
  },
)
```

**Use Cases:**
- Onboarding animations
- One-time celebrations (level up, achievement unlocked)
- Tutorial steps
- Intro animations

### 3. Repeat N Times

Play the animation a specific number of times before stopping.

```dart
SVGAEasyPlayer(
  assetsName: "assets/notification.svga",
  loops: 3, // Play 1 time + repeat 3 times = 4 total plays
  onFinished: () {
    print("All repetitions completed!");
    // Perform action after all loops
  },
)
```

**Important:** The `loops` parameter represents **additional repeats** after the first play:
- `loops: 0` = Play 1 time total (no repeats)
- `loops: 1` = Play 2 times total (1 initial + 1 repeat)
- `loops: 3` = Play 4 times total (1 initial + 3 repeats)

**Use Cases:**
- Limited celebrations or attention grabbers
- Countdown animations
- Notification alerts (play 2-3 times to grab attention)
- Intro sequences with limited repetition

## API Reference

### SVGAEasyPlayer Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `resUrl` | `String?` | `null` | URL to load SVGA from network |
| `assetsName` | `String?` | `null` | Asset path to load SVGA from app bundle |
| `fit` | `BoxFit` | `BoxFit.contain` | How to fit the animation in its container |
| `loops` | `int?` | `null` | Number of times to repeat (null = infinite) |
| `onFinished` | `VoidCallback?` | `null` | Callback when animation finishes |
| `useCache` | `bool` | `true` | Whether to use caching for this animation |
| `clearCacheOnDispose` | `bool` | `false` | Clear from cache when widget is disposed |

### Loops Parameter Behavior

```dart
// Infinite repeat (default)
loops: null  // Never calls onFinished

// Play once
loops: 0     // Plays 1 time, then calls onFinished

// Repeat N times
loops: N     // Plays (N + 1) times total, then calls onFinished
```

### onFinished Callback

The `onFinished` callback is called when:
- The animation completes for `loops: 0` (play once)
- All repetitions complete for `loops: N` (repeat N times)
- **Never called** for `loops: null` (infinite repeat)

```dart
onFinished: () {
  // This code runs when animation finishes
  // Safe to navigate, show dialogs, update state, etc.
}
```

## Complete Examples

### Example 1: Splash Screen with One-Time Animation

```dart
class SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SVGAEasyPlayer(
          assetsName: "assets/splash_animation.svga",
          loops: 0, // Play once
          onFinished: () {
            // Navigate to home screen after animation
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => HomeScreen()),
            );
          },
        ),
      ),
    );
  }
}
```

### Example 2: Achievement Unlocked (Repeat 3 Times)

```dart
class AchievementWidget extends StatefulWidget {
  @override
  State<AchievementWidget> createState() => _AchievementWidgetState();
}

class _AchievementWidgetState extends State<AchievementWidget> {
  bool _showAnimation = true;

  @override
  Widget build(BuildContext context) {
    if (!_showAnimation) return SizedBox.shrink();
    
    return SVGAEasyPlayer(
      assetsName: "assets/achievement.svga",
      loops: 2, // Play 3 times total (1 + 2 repeats)
      onFinished: () {
        setState(() {
          _showAnimation = false; // Hide after animation
        });
      },
    );
  }
}
```

### Example 3: Loading Indicator (Infinite)

```dart
class LoadingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SVGAEasyPlayer(
      assetsName: "assets/loading.svga",
      // No loops parameter = infinite repeat (default)
      fit: BoxFit.contain,
    );
  }
}
```

### Example 4: Notification Alert (Play 2 Times)

```dart
void showNotificationAnimation() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      content: SizedBox(
        height: 200,
        child: SVGAEasyPlayer(
          assetsName: "assets/notification_bell.svga",
          loops: 1, // Play 2 times (1 + 1 repeat)
          onFinished: () {
            Navigator.of(context).pop(); // Close dialog when done
          },
        ),
      ),
    ),
  );
}
```

## Migration Guide

### Upgrading from Previous Version

The new features are **backward compatible**. Existing code will continue to work without changes:

```dart
// Old code (still works - infinite repeat by default)
SVGAEasyPlayer(assetsName: "assets/animation.svga")

// Explicitly infinite (same behavior)
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  loops: null,
)
```

### Adding Playback Control to Existing Code

If you want to add playback control to existing animations:

**Before:**
```dart
SVGAEasyPlayer(assetsName: "assets/animation.svga")
```

**After (play once):**
```dart
SVGAEasyPlayer(
  assetsName: "assets/animation.svga",
  loops: 0,
  onFinished: () {
    // Handle completion
  },
)
```

## Testing the Feature

The example app includes a comprehensive demo of all playback modes. To run it:

```bash
cd example
flutter run
```

Then tap on **"Playback Modes Example"** to see all three modes in action.

## Implementation Details

### How It Works

1. When `loops` is `null`, the player uses `controller.repeat()` for infinite looping
2. When `loops` is set (0 or N), the player uses `controller.forward()` and tracks completion
3. A status listener counts completed loops and calls `onFinished` when the target is reached
4. The loop counter resets when the source changes (new URL or asset)

### Performance Considerations

- **Memory:** No additional memory overhead - uses existing controller infrastructure
- **CPU:** Minimal overhead from status listener (only runs on animation status changes)
- **Callbacks:** `onFinished` is called once per completion, safe for navigation or state updates

## Common Patterns

### Pattern 1: Auto-Navigate After Animation

```dart
SVGAEasyPlayer(
  assetsName: "assets/intro.svga",
  loops: 0,
  onFinished: () => Navigator.pushReplacement(...),
)
```

### Pattern 2: Show/Hide Animation

```dart
bool _show = true;
// ...
if (_show)
  SVGAEasyPlayer(
    assetsName: "assets/effect.svga",
    loops: 0,
    onFinished: () => setState(() => _show = false),
  )
```

### Pattern 3: Chain Animations

```dart
int _step = 0;
final animations = ["step1.svga", "step2.svga", "step3.svga"];
// ...
SVGAEasyPlayer(
  assetsName: "assets/${animations[_step]}",
  loops: 0,
  onFinished: () {
    if (_step < animations.length - 1) {
      setState(() => _step++);
    }
  },
)
```

### Pattern 4: Replay Button

```dart
int _key = 0; // Force rebuild
// ...
SVGAEasyPlayer(
  key: ValueKey(_key),
  assetsName: "assets/animation.svga",
  loops: 0,
  onFinished: () => print("Done!"),
)
// ...
ElevatedButton(
  onPressed: () => setState(() => _key++),
  child: Text("Replay"),
)
```

## Troubleshooting

### Animation Doesn't Stop

**Problem:** Animation keeps looping even with `loops: 0`

**Solution:** Ensure you're creating a new `SVGAEasyPlayer` instance, not reusing the same controller. Use a `key` if needed:

```dart
SVGAEasyPlayer(
  key: ValueKey(uniqueIdentifier),
  loops: 0,
  // ...
)
```

### onFinished Not Called

**Problem:** The callback never executes

**Possible causes:**
1. `loops: null` (infinite) - callback is never called by design
2. Animation source failed to load - check for errors in debug console
3. Widget disposed before animation completed

### Animation Plays Wrong Number of Times

**Problem:** Animation plays different number of times than expected

**Remember:** `loops` represents **additional** repeats:
- `loops: 0` = 1 total play
- `loops: 1` = 2 total plays  
- `loops: 3` = 4 total plays

## Summary

The enhanced `SVGAEasyPlayer` gives you three simple but powerful options:

✅ **Infinite loops** for continuous animations (default)  
✅ **Play once** for one-time events with completion callback  
✅ **Repeat N times** for limited repetitions with completion callback

All features are backward compatible and easy to use. See the example app for live demonstrations!
