import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

/// Example demonstrating cache control features in SVGAEasyPlayer
class CacheControlExample extends StatefulWidget {
  const CacheControlExample({super.key});

  @override
  State<CacheControlExample> createState() => _CacheControlExampleState();
}

class _CacheControlExampleState extends State<CacheControlExample> {
  Map<String, dynamic> _cacheStats = {};
  int _withCacheKey = 0;
  int _withoutCacheKey = 0;
  int _clearOnDisposeKey = 0;
  bool _showClearOnDisposeWidget = true;

  @override
  void initState() {
    super.initState();
    _refreshCacheStats();
  }

  Future<void> _refreshCacheStats() async {
    final stats = await SVGACache.shared.getStats();
    setState(() {
      _cacheStats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Control Example'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCacheStats,
            tooltip: 'Refresh Cache Stats',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              color: Colors.teal,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SVGAEasyPlayer Cache Control',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Control caching behavior per widget:\n'
                      '• useCache: Enable/disable caching\n'
                      '• clearCacheOnDispose: Auto-cleanup',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _buildCacheStatsChip(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Cache Stats Section
            _buildCacheStatsCard(),
            const SizedBox(height: 24),

            // Example 1: With Cache (Default)
            _buildCacheExample(
              title: '1. With Cache (Default)',
              description:
                  'useCache: true (default)\nLoads from cache if available, stores after first load',
              color: Colors.green,
              key: _withCacheKey,
              useCache: true,
              codeSnippet: '''
SVGAEasyPlayer(
  assetsName: "assets/angel.svga",
  useCache: true, // default
  loops: 0,
)''',
              onReload: () {
                setState(() => _withCacheKey++);
                Future.delayed(const Duration(milliseconds: 500), _refreshCacheStats);
              },
            ),
            const SizedBox(height: 24),

            // Example 2: Without Cache
            _buildCacheExample(
              title: '2. Without Cache',
              description:
                  'useCache: false\nBypass cache completely, always loads fresh data',
              color: Colors.orange,
              key: _withoutCacheKey,
              useCache: false,
              codeSnippet: '''
SVGAEasyPlayer(
  assetsName: "assets/sample.svga",
  useCache: false, // bypass cache
  loops: 0,
)''',
              onReload: () {
                setState(() => _withoutCacheKey++);
                Future.delayed(const Duration(milliseconds: 500), _refreshCacheStats);
              },
            ),
            const SizedBox(height: 24),

            // Example 3: Clear Cache on Dispose
            _buildClearOnDisposeExample(),
            const SizedBox(height: 24),

            // Global Cache Management
            _buildGlobalCacheManagement(),
            const SizedBox(height: 24),

            // Use Cases
            _buildUseCasesCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheStatsChip() {
    final size = _cacheStats['size'] ?? 0;
    final count = _cacheStats['fileCount'] ?? 0;
    final enabled = _cacheStats['enabled'] ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.cancel,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '$count files • ${(size / 1024).toStringAsFixed(1)} KB',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheStatsCard() {
    final enabled = _cacheStats['enabled'] ?? false;
    final size = _cacheStats['size'] ?? 0;
    final maxSize = _cacheStats['maxSize'] ?? 1;
    final count = _cacheStats['fileCount'] ?? 0;
    final maxAge = _cacheStats['maxAge'] ?? 7;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'Cache Statistics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _refreshCacheStats,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const Divider(),
            _buildStatRow('Status', enabled ? 'Enabled ✓' : 'Disabled ✗',
                enabled ? Colors.green : Colors.red),
            _buildStatRow('Files', '$count', Colors.blue),
            _buildStatRow(
                'Size', '${(size / 1024).toStringAsFixed(2)} KB', Colors.orange),
            _buildStatRow('Max Size',
                '${(maxSize / (1024 * 1024)).toStringAsFixed(0)} MB', Colors.grey),
            _buildStatRow('Max Age', '$maxAge days', Colors.grey),
            _buildStatRow('Usage',
                '${((size / maxSize) * 100).toStringAsFixed(1)}%', Colors.purple),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheExample({
    required String title,
    required String description,
    required Color color,
    required int key,
    required bool useCache,
    required String codeSnippet,
    required VoidCallback onReload,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description,
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color, width: 2),
              ),
              child: Center(
                child: SVGAEasyPlayer(
                  key: ValueKey(key),
                  assetsName: useCache ? "assets/angel.svga" : "assets/sample.svga",
                  useCache: useCache,
                  loops: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildCodeSnippet(codeSnippet),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onReload,
                icon: const Icon(Icons.replay),
                label: const Text('Reload Animation'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClearOnDisposeExample() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('3. Clear Cache on Dispose',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'clearCacheOnDispose: true\nAutomatically removes from cache when widget is disposed',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (_showClearOnDisposeWidget)
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Center(
                  child: SVGAEasyPlayer(
                    key: ValueKey(_clearOnDisposeKey),
                    assetsName: "assets/pin_jump.svga",
                    useCache: true,
                    clearCacheOnDispose: true,
                    loops: 0,
                  ),
                ),
              )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey, width: 2),
                ),
                child: const Center(
                  child: Text(
                    'Widget Disposed\nCache Cleared',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _buildCodeSnippet('''
SVGAEasyPlayer(
  assetsName: "assets/pin_jump.svga",
  clearCacheOnDispose: true, // auto-cleanup
  loops: 0,
)'''),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showClearOnDisposeWidget = true;
                        _clearOnDisposeKey++;
                      });
                      Future.delayed(
                          const Duration(milliseconds: 500), _refreshCacheStats);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Show Widget'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showClearOnDisposeWidget
                        ? () {
                            setState(() => _showClearOnDisposeWidget = false);
                            Future.delayed(const Duration(milliseconds: 500),
                                _refreshCacheStats);
                          }
                        : null,
                    icon: const Icon(Icons.delete),
                    label: const Text('Dispose & Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalCacheManagement() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.settings, color: Colors.teal),
                SizedBox(width: 8),
                Text(
                  'Global Cache Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await SVGACache.shared.clear();
                  await _refreshCacheStats();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All cache cleared!')),
                    );
                  }
                },
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Clear All Cache'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      SVGACache.shared.setEnabled(true);
                      _refreshCacheStats();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Caching enabled globally')),
                      );
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Enable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      SVGACache.shared.setEnabled(false);
                      _refreshCacheStats();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Caching disabled globally')),
                      );
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Disable'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUseCasesCard() {
    return Card(
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
                  'Cache Control Use Cases',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildUseCase(
              '✅ useCache: true (Default)',
              'Frequently used animations, app intro, loading indicators',
              'Fast loading, reduced bandwidth',
            ),
            const Divider(),
            _buildUseCase(
              '🚫 useCache: false',
              'Dynamic content, real-time updates, testing',
              'Always fresh data, no stale content',
            ),
            const Divider(),
            _buildUseCase(
              '🗑️ clearCacheOnDispose: true',
              'One-time celebrations, temporary effects, privacy-sensitive animations',
              'Automatic cleanup, saves storage',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUseCase(String title, String description, String benefit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '💡 $benefit',
              style: const TextStyle(fontSize: 12, color: Colors.teal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeSnippet(String code) {
    return Container(
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
            code,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
