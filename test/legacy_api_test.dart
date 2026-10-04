// The original parameter names must keep working for apps written against
// 0.0.x and 0.1.0.
// ignore_for_file: deprecated_member_use_from_same_package
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old parameter names map onto the new ones', () {
    const forever = SVGAEasyPlayer(assetsName: 'a.svga');
    expect(forever.asset, 'a.svga');
    expect(forever.url, isNull);
    expect(forever.playCount, isNull);
    expect(forever.muted, isFalse);
    expect(forever.keepLastFrame, isFalse);

    const once = SVGAEasyPlayer(
      resUrl: 'https://x/a.svga',
      loops: 0,
      isMute: true,
      clearsAfterStop: false,
    );
    expect(once.url, 'https://x/a.svga');
    expect(once.playCount, 1);
    expect(once.muted, isTrue);
    expect(once.keepLastFrame, isTrue);

    expect(const SVGAEasyPlayer(loops: 2).playCount, 3);
    expect(const SVGAEasyPlayer(loops: 2).loops, 2);
    expect(once.resUrl, once.url);
    expect(once.isMute, isTrue);
    expect(once.clearsAfterStop, isFalse);
  });

  test('named constructors set the source', () {
    const network = SVGAEasyPlayer.network('https://x/a.svga', playCount: 2);
    expect(network.url, 'https://x/a.svga');
    expect(network.asset, isNull);
    expect(network.playCount, 2);

    const asset = SVGAEasyPlayer.asset('a.svga', muted: true);
    expect(asset.asset, 'a.svga');
    expect(asset.url, isNull);
    expect(asset.muted, isTrue);
  });

  testWidgets('the controller still accepts isMute', (tester) async {
    final controller = SVGAAnimationController(vsync: tester)..isMute = true;
    addTearDown(controller.dispose);
    expect(controller.muted, isTrue);
    expect(controller.isMute, isTrue);
  });

  test('a play count below one is rejected', () {
    expect(
      () => SVGAEasyPlayer.asset('a.svga', playCount: 0),
      throwsA(isA<AssertionError>()),
    );
  });
}
