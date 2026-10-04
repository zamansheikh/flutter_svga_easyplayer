import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga_easyplayer/flutter_svga_easyplayer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lets asset loading and image decoding finish, then rebuilds.
Future<void> settleLoad(WidgetTester tester) async {
  for (var round = 0; round < 10; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
}

void main() {
  test('every listed gift is bundled', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(gifts, hasLength(10));
    for (final gift in gifts) {
      final movie = await SVGAParser.shared.decodeFromAssets(assetOf(gift));
      expect(movie.params.frames, greaterThan(0), reason: gift);
      movie.dispose();
    }
  });

  testWidgets('the gallery plays gifts and opens one full screen', (
    tester,
  ) async {
    await tester.pumpWidget(const GiftGalleryApp());
    expect(find.text('Gift gallery'), findsOneWidget);
    await settleLoad(tester);
    expect(find.byType(SVGAImage), findsWidgets);
    expect(find.byIcon(Icons.broken_image), findsNothing);

    await tester.tap(find.text('Kiss'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await settleLoad(tester);
    expect(find.text('Once'), findsOneWidget);
    expect(find.byType(SVGAImage), findsWidgets);

    await tester.tap(find.text('Once'));
    await tester.pump();
    await settleLoad(tester);
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(find.text('Finished'), findsOneWidget);
  });
}
