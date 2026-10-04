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
              child: SVGAEasyPlayer(
                assetsName: assetOf(gift),
                isMute: true,
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
  /// `null` loops forever, `0` plays once, `2` plays three times.
  int? _loops;
  bool _muted = false;

  /// Changes whenever playback should start over.
  int _run = 0;

  void _setLoops(int? loops) => setState(() {
    _loops = loops;
    _run++;
  });

  @override
  Widget build(BuildContext context) {
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
        child: SVGAEasyPlayer(
          key: ValueKey(_run),
          assetsName: widget.asset,
          resUrl: widget.url,
          loops: _loops,
          isMute: _muted,
          clearsAfterStop: false,
          placeholder: const CircularProgressIndicator(),
          errorBuilder: (context, error) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text(switch (error) {
              SVGANetworkException(:final statusCode?) =>
                'The server answered with HTTP $statusCode.',
              SVGANetworkException() => 'Could not reach the server.',
              SVGATimeoutException() => 'The download took too long.',
              SVGAFormatException() => 'That is not an SVGA 2.x file.',
              _ => 'Could not load the animation.',
            }, textAlign: TextAlign.center),
          ),
          onFinished: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Finished'))),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<int?>(
            segments: const [
              ButtonSegment(value: null, label: Text('Loop')),
              ButtonSegment(value: 0, label: Text('Once')),
              ButtonSegment(value: 2, label: Text('3 times')),
            ],
            selected: {_loops},
            onSelectionChanged: (selection) => _setLoops(selection.single),
          ),
        ),
      ),
    );
  }
}
