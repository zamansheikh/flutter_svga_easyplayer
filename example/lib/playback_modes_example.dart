import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

/// Example demonstrating the three playback modes of SVGAEasyPlayer:
/// 1. Infinite repeat (default)
/// 2. Play once
/// 3. Repeat N times
class PlaybackModesExample extends StatefulWidget {
  const PlaybackModesExample({super.key});

  @override
  State<PlaybackModesExample> createState() => _PlaybackModesExampleState();
}

class _PlaybackModesExampleState extends State<PlaybackModesExample> {
  final String _infiniteStatus = "Playing infinitely...";
  String _playOnceStatus = "Ready to play once";
  String _repeatNTimesStatus = "Ready to repeat 3 times";
  int _playOnceCount = 0;
  int _repeatNTimesCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SVGAEasyPlayer Playback Modes'),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Card(
              color: Colors.deepPurple,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SVGAEasyPlayer Playback Modes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This example demonstrates three playback modes:\n'
                      '• Infinite repeat (default behavior)\n'
                      '• Play once with onFinished callback\n'
                      '• Repeat N times with onFinished callback',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Mode 1: Infinite Repeat (Default)
            _buildSection(
              title: '1. Infinite Repeat (Default)',
              description:
                  'loops: null (default)\nPlays forever without stopping',
              status: _infiniteStatus,
              statusColor: Colors.blue,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                child: const Center(
                  child: SVGAEasyPlayer(
                    assetsName: "assets/pin_jump.svga",
                    // loops: null is the default - infinite repeat
                    // No onFinished callback needed since it never finishes
                  ),
                ),
              ),
              codeSnippet: '''
SVGAEasyPlayer(
  assetsName: "assets/pin_jump.svga",
  // loops: null (default)
  // Repeats infinitely
)''',
            ),

            const SizedBox(height: 24),

            // Mode 2: Play Once
            _buildSection(
              title: '2. Play Once',
              description: 'loops: 0\nPlays animation one time, then stops',
              status: _playOnceStatus,
              statusColor: Colors.green,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Center(
                  child: SVGAEasyPlayer(
                    key: ValueKey(_playOnceCount), // Force rebuild
                    assetsName: "assets/angel.svga",
                    loops: 0, // Play once
                    onFinished: () {
                      setState(() {
                        _playOnceStatus =
                            "✓ Animation finished! (Played ${_playOnceCount + 1} time${_playOnceCount == 0 ? '' : 's'})";
                      });
                    },
                  ),
                ),
              ),
              codeSnippet: '''
SVGAEasyPlayer(
  assetsName: "assets/angel.svga",
  loops: 0, // Play once
  onFinished: () {
    print("Animation completed!");
    // Handle completion
  },
)''',
              actionButton: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _playOnceCount++;
                    _playOnceStatus = "Playing...";
                  });
                },
                icon: const Icon(Icons.replay),
                label: const Text('Replay Once'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mode 3: Repeat N Times
            _buildSection(
              title: '3. Repeat 3 Times',
              description:
                  'loops: 3\nPlays animation 4 times total (1 initial + 3 repeats)',
              status: _repeatNTimesStatus,
              statusColor: Colors.orange,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange, width: 2),
                ),
                child: Center(
                  child: SVGAEasyPlayer(
                    key: ValueKey(_repeatNTimesCount), // Force rebuild
                    assetsName: "assets/sample.svga",
                    loops: 3, // Repeat 3 times (plays 4 times total)
                    onFinished: () {
                      setState(() {
                        _repeatNTimesStatus =
                            "✓ All repetitions completed! (Total: ${_repeatNTimesCount + 1} session${_repeatNTimesCount == 0 ? '' : 's'})";
                      });
                    },
                  ),
                ),
              ),
              codeSnippet: '''
SVGAEasyPlayer(
  assetsName: "assets/sample.svga",
  loops: 3, // Repeat 3 times (4 total plays)
  onFinished: () {
    print("All repetitions completed!");
    // Navigate to next screen, etc.
  },
)''',
              actionButton: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _repeatNTimesCount++;
                    _repeatNTimesStatus = "Playing with 3 repeats...";
                  });
                },
                icon: const Icon(Icons.replay),
                label: const Text('Restart (3x)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Additional Examples Section
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Common Use Cases',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildUseCase(
                      '🔄 Infinite Loop',
                      'Background animations, loading indicators, ambient effects',
                      'loops: null (default)',
                    ),
                    const Divider(),
                    _buildUseCase(
                      '▶️ Play Once',
                      'Onboarding animations, one-time celebrations, tutorial steps',
                      'loops: 0, onFinished: () { ... }',
                    ),
                    const Divider(),
                    _buildUseCase(
                      '🔢 Repeat N Times',
                      'Limited celebrations, attention grabbers, countdown animations',
                      'loops: N, onFinished: () { ... }',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String description,
    required String status,
    required Color statusColor,
    required Widget child,
    required String codeSnippet,
    Widget? actionButton,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: statusColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.code, color: Colors.white70, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Code Example',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    codeSnippet,
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: actionButton),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUseCase(String emoji, String description, String code) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
