import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

/// End-to-end demo of [SVGAPrecacheManager].
///
/// You can trigger a precache batch from any screen — it does not need to live
/// inside `main()`. Typical places to call it:
///
///   * `main()` — warm the cache for the very first screen (fire-and-forget).
///   * `HomeScreen.initState()` — warm animations the user is about to see.
///   * Right after login — pull in the user's favourite/unlocked stickers.
///   * Inside a "Download for offline use" button.
///
/// The parser already reads from the same cache, so once a URL is precached,
/// `SVGAEasyPlayer(resUrl: theSameUrl)` plays instantly without another
/// network round-trip.
class PrecacheExample extends StatefulWidget {
  const PrecacheExample({super.key});

  @override
  State<PrecacheExample> createState() => _PrecacheExampleState();
}

class _PrecacheExampleState extends State<PrecacheExample> {
  static const _urls = <String>[
    'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/EmptyState.svga',
    'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/HamburgerArrow.svga',
    'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/PinJump.svga',
    'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/TwitterHeart.svga',
    'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/heartbeat.svga',
    'https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/rose.svga',
  ];

  int _completed = 0;
  int _total = 0;
  int _hits = 0;
  int _fetched = 0;
  int _failed = 0;
  String _lastSource = '';
  bool _running = false;
  SVGAPrecacheResult? _result;

  @override
  void initState() {
    super.initState();
    // Example of calling precache from any screen's initState.
    // Comment this out if you only want the buttons to trigger it.
    _startPrecache();
  }

  Future<void> _startPrecache({Duration? delay}) async {
    if (_running) return;
    setState(() {
      _running = true;
      _completed = 0;
      _hits = 0;
      _fetched = 0;
      _failed = 0;
      _total = _urls.length;
      _lastSource = '';
      _result = null;
    });

    final result = await SVGAPrecacheManager.shared.precache(
      _urls,
      delay: delay,
      concurrency: 3,
      timeout: const Duration(seconds: 15),
      onProgress: (done, total, source, success) {
        if (!mounted) return;
        setState(() {
          _completed = done;
          _total = total;
          _lastSource = source;
          if (success) {
            // We cannot tell from the callback alone whether it was a hit or a
            // fresh download — the final `SVGAPrecacheResult` has that split.
          } else {
            _failed++;
          }
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
      _hits = result.cacheHits;
      _fetched = result.fetched;
      _failed = result.failed;
    });
  }

  Future<void> _clearAndRetry() async {
    await SVGACache.shared.clear();
    if (!mounted) return;
    await _startPrecache();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? 0.0 : _completed / _total;
    return Scaffold(
      appBar: AppBar(title: const Text('Silent Precache (new!)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Calling SVGAPrecacheManager.shared.precache(urls) warms the '
              'local cache in the background. When you later render an '
              'SVGAEasyPlayer with the same URL, it plays instantly from disk.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _running ? progress : (_result != null ? 1.0 : 0.0),
            ),
            const SizedBox(height: 8),
            Text(
              'Progress: $_completed / $_total'
              '${_running ? ' · running…' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_lastSource.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Last: $_lastSource',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(Icons.check_circle, 'Cache hits: $_hits', Colors.green),
                _chip(Icons.cloud_download, 'Fetched: $_fetched', Colors.blue),
                _chip(Icons.error_outline, 'Failed: $_failed', Colors.red),
              ],
            ),
            if (_result != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _result.toString(),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _running ? null : () => _startPrecache(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Precache now'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _running
                        ? null
                        : () => _startPrecache(
                            delay: const Duration(seconds: 2),
                          ),
                    icon: const Icon(Icons.timer),
                    label: const Text('Precache in 2s'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _running
                        ? () => SVGAPrecacheManager.shared.cancel()
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _running ? null : _clearAndRetry,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear & retry'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            Text(
              'Tap any URL below to play it. After a successful precache, '
              'these load instantly — no loading indicator flash.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Expanded(
              child: ListView.separated(
                itemCount: _urls.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final url = _urls[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.play_circle_outline),
                    title: Text(
                      url.split('/').last,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _PrecachedPlayerScreen(url: url),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.08),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }
}

class _PrecachedPlayerScreen extends StatelessWidget {
  final String url;
  const _PrecachedPlayerScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(url.split('/').last)),
      body: Center(
        child: SVGAEasyPlayer(resUrl: url, fit: BoxFit.contain),
      ),
    );
  }
}
