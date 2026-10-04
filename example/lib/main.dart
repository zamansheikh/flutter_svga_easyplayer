import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';

/// The gift animations bundled in `assets/`.
const gifts = [
  'kiss',
  'green-hat',
  'corgi-cloud',
  'blue-rose-heart',
  'blessing-bag',
  'heart-jar',
  'flying-pig-hearts',
  'rocket-butterflies',
  'bunny-birthday-cake',
  'slipper-slap',
];

String assetOf(String gift) => 'assets/$gift.svga';

/// `corgi-cloud` → `Corgi cloud`
String titleOf(String gift) {
  final words = gift.replaceAll('-', ' ');
  return words[0].toUpperCase() + words.substring(1);
}

void main() => runApp(const GiftGalleryApp());

class GiftGalleryApp extends StatelessWidget {
  const GiftGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SVGA gift gallery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: const GalleryScreen(),
    );
  }
}

/// A grid of every gift, each one playing on a loop.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  Future<void> _openUrl(BuildContext context) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Play from a URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'https://example.com/gift.svga',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Play'),
          ),
        ],
      ),
    );
    if (url == null || url.trim().isEmpty || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GiftScreen(title: 'From URL', url: url.trim()),
      ),
    );
  }

  Future<void> _showCache(BuildContext context) async {
    final stats = await SVGACache.shared.getStats();
    if (!context.mounted) return;
    final megabytes = (stats['size'] as int) / (1024 * 1024);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disk cache'),
        content: Text(
          '${stats['fileCount']} files, ${megabytes.toStringAsFixed(1)} MB\n'
          'In memory, idle: '
          '${(SVGAMemoryCache.shared.idleBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await SVGACache.shared.clear();
              SVGAMemoryCache.shared.clear();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift gallery'),
        actions: [
          IconButton(
            tooltip: 'Play from a URL',
            icon: const Icon(Icons.link),
            onPressed: () => _openUrl(context),
          ),
          IconButton(
            tooltip: 'Cache',
            icon: const Icon(Icons.storage),
            onPressed: () => _showCache(context),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemCount: gifts.length,
        itemBuilder: (context, index) => _GiftTile(gift: gifts[index]),
      ),
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({required this.gift});

  final String gift;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                GiftScreen(title: titleOf(gift), asset: assetOf(gift)),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SVGAEasyPlayer.asset(
                assetOf(gift),
                muted: true,
                allowDrawingOverflow: false,
                placeholder: const Center(child: CircularProgressIndicator()),
                errorBuilder: (_, _) =>
                    const Center(child: Icon(Icons.broken_image)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(titleOf(gift), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// One gift, full screen, with playback controls.
class GiftScreen extends StatefulWidget {
  const GiftScreen({super.key, required this.title, this.asset, this.url});

  final String title;
  final String? asset;
  final String? url;

  @override
  State<GiftScreen> createState() => _GiftScreenState();
}

class _GiftScreenState extends State<GiftScreen> {
  /// How many times to play; `null` repeats forever.
  int? _playCount;
  bool _muted = false;

  /// Changes whenever playback should start over.
  int _run = 0;

  void _setPlayCount(int? playCount) => setState(() {
    _playCount = playCount;
    _run++;
  });

  Widget _error(BuildContext context, Object error) => Padding(
    padding: const EdgeInsets.all(24),
    child: Text(switch (error) {
      SVGANetworkException(:final statusCode?) =>
        'The server answered with HTTP $statusCode.',
      SVGANetworkException() => 'Could not reach the server.',
      SVGATimeoutException() => 'The download took too long.',
      SVGAFormatException() => 'That is not an SVGA 2.x file.',
      _ => 'Could not load the animation.',
    }, textAlign: TextAlign.center),
  );

  void _finished() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Finished')));

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _muted ? 'Unmute' : 'Mute',
            icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
            onPressed: () => setState(() => _muted = !_muted),
          ),
        ],
      ),
      body: Center(
        child: asset != null
            ? SVGAEasyPlayer.asset(
                asset,
                key: ValueKey(_run),
                playCount: _playCount,
                muted: _muted,
                keepLastFrame: true,
                placeholder: const CircularProgressIndicator(),
                errorBuilder: _error,
                onFinished: _finished,
              )
            : SVGAEasyPlayer.network(
                widget.url!,
                key: ValueKey(_run),
                playCount: _playCount,
                muted: _muted,
                keepLastFrame: true,
                placeholder: const CircularProgressIndicator(),
                errorBuilder: _error,
                onFinished: _finished,
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<int?>(
            segments: const [
              ButtonSegment(value: null, label: Text('Loop')),
              ButtonSegment(value: 1, label: Text('Once')),
              ButtonSegment(value: 3, label: Text('3 times')),
            ],
            selected: {_playCount},
            onSelectionChanged: (selection) => _setPlayCount(selection.single),
          ),
        ),
      ),
    );
  }
}
